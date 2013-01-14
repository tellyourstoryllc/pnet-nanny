require 'phashion'

class Photo < Peanut::ActivePeanut::Base
  include Peanut::Redis::Attributes
  include Peanut::Redis::Objects

  list :notification_queue, :global=>true

  set :task_names  # The names of all tasks to be run on this photo

  set :tasks_passed
  set :tasks_failed
  set :tasks_undecided

  attr_accessible :url, :fingerprint, :created_at
  attr_accessible :status # pending, delivering, or completed

  redis_attr :passthru
  redis_attr :callback_url
  redis_attr :max_votes, :min_votes
  
  class << self

    def process_notification_queue
      success = 0
      self.notification_queue.each do |pid|
        if foto = Photo.find(pid)
          if response = foto.deliver_callback
            self.notification_queue.delete(pid)
            success += 1
          end
        end
      end
      success
    end

    def fingerprint_url(image_url)
      begin
        if phile = Phashion::Image.new(tempfile_for_url(image_url))
          fingerprint = phile.fingerprint
          delete_tempfile_for_url(image_url)
          fingerprint
        end
      rescue Errno::ECONNREFUSED
        log_error("Error fingerprinting - connection refused to #{image_url}")
        nil
      rescue RuntimeError
        log_error("RuntimeError fingerprinting #{image_url}")
        nil
      rescue SocketError
        log_error("SocketError fingerprinting #{image_url}")
        nil        
      end
    end
    
    def tempfile_for_url(url, create_if_needed=true)
      # find the extension
      /.+(\.\w+)$/ =~ url
      extension = $1 || '.tmp'
      filename = "#{Rails.root}/tmp/#{Peanut::Toolkit.hash(url)}#{extension}"

      if File.exists?(filename)
        return filename
      elsif create_if_needed and data = Net::HTTP.get(URI.parse(url))
        File.open(filename, 'wb') { |f| f.write(data) }
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

  def destroy
    tasks.each { |t| t.remove_photo(self) }
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
  
  def tasks
    task_names.members.map { |name| Task.find(name) }
  end

  def add_task(task)
    unless self.tasks.include?(task)
      self.task_names << task.name
      task.add_photo(self)
    end
  end

  def remove_task(task)
    task.remove_photo(self)
    [task_names, tasks_passed, tasks_failed, tasks_undecided].each { |s| s.delete(task.name) }
  end

  def task_votes(task_name)
    Vote.where("photo_id = :pid AND taskname = :task", :pid=>self.id, :task=>task_name)
  end

  def pass_votes(task_name)
    self.task_votes(task_name).where("decision = 'pass'")
  end

  def fail_votes(task_name)
    self.task_votes(task_name).where("decision = 'fail'")
  end

  # ---------------------------------------------------------------------------

  def create_vote(decision, task_name, worker)

    unless vote = Vote.find_by_worker_id_and_photo_id_and_taskname(worker.id, self.id, task_name)
      vote = Vote.new
      vote.worker_id = worker.id
      vote.photo_id = self.id   
      vote.taskname = task_name  
    end

    vote.decision = case decision.to_s
    when 'pass', 'true', 'yes'
      'pass'
    when 'fail', 'false', 'no'
      'fail'
    end

    vote.save
    self.tally_votes(task_name)
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
      if (pass.to_f / all.to_f) * 100 >= approval_ratio.to_i
        mark_passed(task_name)
      elsif ((fail.to_f / all.to_f) * 100 >= rejection_ratio.to_i)
        mark_failed(task_name)
      elsif all >= maximum_votes.to_i
        mark_unclear(task_name)
      else
        # No decision yet. Wait for more votes...
      end
    end

  end    

  def mark_passed(task_name)
    Task.find(task_name).remove_photo(self)
    self.tasks_passed << task_name
    self.pass_votes(task_name).update_all(:correct=>:yes)
    self.fail_votes(task_name).update_all(:correct=>:no)
    self.check_task_completion
  end
  
  def mark_failed(task_name)
    Task.find(task_name).remove_photo(self)
    self.tasks_failed << task_name
    self.pass_votes(task_name).update_all(:correct=>:no)
    self.fail_votes(task_name).update_all(:correct=>:yes)
    self.check_task_completion
  end
  
  def mark_unclear
    Task.find(task_name).remove_photo(self)
    self.tasks_undecided << task_name
    self.task_votes(task_name).update_all(:correct=>:unknown)
    self.check_task_completion
  end

  # Check if *all* assigned tasks have been completed.
  def check_task_completion
    if self.status == 'pending'
      completed = self.tasks_passed.members + self.tasks_failed.members + self.tasks_undecided.members
      if self.task_names.count > 0 and completed.count == self.task_names.count
        self.notification_queue << self.id  
        self.status = 'delivering'
        self.save
      end
    end  
  end

  def deliver_callback
    passed = self.tasks_passed.members
    failed = self.tasks_failed.members
    undecided = self.tasks_undecided.members
    begin
      response = HTTParty.post(self.callback_url, :body=>{:passed=>passed, :failed=>failed, :undecided=>undecided, :passthru=>self.passthru})
      if response.code.to_i == 200 
        true
      else
        log_error "Callback failed with HTTP code {response.code}: #{self.callback_url}."
        false
      end
    rescue Exception=>e
      log_error "Callback failed: #{self.callback_url}. #{e}"
      false
    end
  end

end