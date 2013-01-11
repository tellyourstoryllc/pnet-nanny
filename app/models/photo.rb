require 'phashion'

class Photo < Peanut::ActivePeanut::Base
  include Peanut::Redis::Attributes
  include Peanut::Redis::Objects

  list :notification_queue, :global=>true

  set :tasks  # All tasks to be run on this photo

  set :tasks_passed
  set :tasks_failed
  set :tasks_undecided

  attr_accessible :url, :fingerprint, :created_at
  attr_accessible :status # pending, delivering, or completed

  redis_attr :passthru
  redis_attr :callback_url
  redis_attr :max_votes, :min_votes
  
  class << self
    
    def search_conditions(options={})

      query_strings = []
      query_hash = {}

      if statuses = options[:status]
        query_strings << 'status in (:status)'
        query_hash[:status] = [statuses].flatten
      end

      if min_id = options[:min_id]
        query_strings << 'id >= :min_id'
        query_hash[:min_id] = min_id
      end

      if min_age = options[:min_age]
        query_strings << 'created_at <= :min_age'
        query_hash[:min_age] = Time.now.utc - min_age.to_i
      end
      
      if fp = options[:fingerprint]
        query_strings << 'fingerprint = :fingerprint'
        query_hash[:fingerprint] = fp        
      end
      
      [query_strings.join(' AND '), query_hash]
    end
    
    # age is specified in days
    def prune(age = 30)
      self.delete_all("(created_at < DATE_SUB(NOW(), INTERVAL #{age} DAY)) AND (status != 'pending')")      
    end    

    def fingerprint_url(image_url)
      begin
        if phile = Phashion::Image.new(tempfile_for_url(image_url))
          fingerprint = phile.fingerprint
          delete_tempfile_for_url(image_url)
          fingerprint
        end
      rescue Errno::ECONNREFUSED
        Rails.logger.error("Error fingerprinting - connection refused to #{image_url}")
        nil
      rescue RuntimeError
        Rails.logger.error("RuntimeError fingerprinting #{image_url}")
        nil
      rescue SocketError
        Rails.logger.error("SocketError fingerprinting #{image_url}")
        nil        
      end
    end
    
    def tempfile_for_url(url, create_if_needed=true)
      # find the extension
      /.+(\.\w+)$/ =~ url
      extension = $1 || '.tmp'
      filename = Rails.root + '/tmp/' + Peanut::Toolkit.hash(url) + extension

      if File.exists?(filename)
        return filename
      elsif create_if_needed and data = Net::HTTP.get(URI.parse(url))
        File.open(filename, 'w') { |f| f.write(data) }
        return filename
      end
    end

    def delete_tempfile_for_url(url)
      if filename = tempfile_for_url(url, false)
        File.unlink filename
      end
    end

  end

  # ---------------------------------------------------------------------------

  def save
    self[:status] ||= 'pending'
    self[:created_at] ||= Time.now.utc
    super
  end

  def fingerprint
    self[:fingerprint] ||= begin
      if @fingerprint_attempted.nil? and self[:url] and fingerprint = Photo.fingerprint_url(self[:url])
        fp = Fingerprint.lookup(fingerprint)
        unless fp
          fp = Fingerprint.new
          fp.value = fingerprint
          fp.save
        end
        fp.photo_ids << self.id
        fingerprint
      else
        @fingerprint_attempted = true
        nil
      end
    end
  end
  
  def add_task(task)
    unless self.tasks.member?(task.name)
      self.tasks << task.name
      Task.add_photo(self)
    end
  end

  def task_votes(task_name)
    Vote.where("photo_id = :pid AND task = :task", :pid=>self.id, :task=>task_name)
  end

  def pass_votes(task_name)
    self.task_votes(task_name).where("decision = 'pass'")
  end

  def fail_votes(task_name)
    self.task_votes(task_name).where("decision = 'fail'")
  end

  # ---------------------------------------------------------------------------

  def create_vote(decision, task_name, worker)

    unless vote = Vote.find_by_worker_id_and_photo_id_and_task(worker.id, self.id, task_name)
      vote = Vote.new
      vote.worker_id = worker_id
      vote.photo_id = self.id      
    end

    vote.decision = case decision
    when 'pass', true, 'yes'
      'pass'
    when 'fail', false, 'no'
      'fail'
    end

    vote.save
    self.tally_votes
  end

  def tally_votes(task_name)

    minimum_votes = Settings.get('min_votes') || 5   # min number needed to approve
    maximum_votes = Settings.get('max_votes') || 10  # auto-rejection if consensus hasn't been reached by this many votes
    approval_ratio = Settings.get('approval_percentage') || 80
    rejection_ratio = Settings.get('reject_percentage') || 60

    all = task_votes(task_name).size
    pass = pass_votes(task_name).size
    fail = fail_votes(task_name).size

    if all >= minimum_votes.to_i

      Task.find(task_name).remove_photo(self)

      if (pass.to_f / all.to_f) * 100 >= approval_ratio.to_i
        mark_passed(task_name)
      elsif ((fail.to_f / all.to_f) * 100 >= rejection_ratio.to_i)
        mark_failed(task_name)
      elsif total_votes >= maximum_votes.to_i
        mark_unclear(task_name)
      end
    end

  end    
    
  def mark_passed(task_name)
    self.tasks_passed << task_name
    self.pass_votes(task_name).update_all(:correct=>:yes)
    self.fail_votes(task_name).update_all(:correct=>:no)
    self.check_task_completion
  end
  
  def mark_failed(task_name)
    self.tasks_failed << task_name
    self.pass_votes(task_name).update_all(:correct=>:no)
    self.fail_votes(task_name).update_all(:correct=>:yes)
    self.check_task_completion
  end
  
  def mark_unclear
    self.tasks_undecided << task_name
    self.task_votes(task_name).update_all(:correct=>:unknown)
    self.check_task_completion
  end

  def check_task_completion
    if self.status == 'pending'
      completed = self.tasks_passed.members + self.tasks_failed.members + self.tasks_undecided.members
      if self.tasks.count > 0 and completed.count == self.tasks.count
        self.notification_queue << self.id  
        self.status = 'delivering'
        self.save
      end
    end  
  end
    
end