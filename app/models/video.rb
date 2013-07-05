class Video < Peanut::RedisOnly
  extend ActiveModel::Naming
  include Peanut::Redis::Objects

  TASK_NAME = 'video_approval'

  attr_accessor :id, :temp_attrs
  hash_key :attrs
  # Sets of task names.
  set :tasks_passed
  set :tasks_failed
  set :tasks_undecided

  class_attribute :attribute_names
  self.attribute_names = %w[
    status client_id url passthru callback_url thumbnail_url
    description info_url creator_url ratings reject_reasons
    message_to_user tags hold_comments
    created_at
  ].map(&:to_sym)

  # These attributes are treated as nested Hashes and serialized to JSON and
  # back.
  class_attribute :nested_attributes
  self.nested_attributes = %w[ratings reject_reasons passthru]

  counter :last_video_id, :global => true

  # SortedSet of pending videos in the queue.
  sorted_set :pending_video_ids, :global => true

  # SortedSet of held videos.
  sorted_set :held_video_ids, :global => true

  class << self

    alias_method :find, :find_by_id

    def primary_key
      'id'
    end

    # Pick some videos for worker to review. Returns an array of Videos.
    def fetch_pending(min_id, per_page, options = {})
      options = {
        :limit => per_page,
      }.merge(options)
      video_ids = self.pending_video_ids.rangebyscore(min_id || "-INF", "INF", options)
      video_ids.map {|id| Video.find_by_id(id) }
    end

    # Pick some videos for worker to review. Returns an array of Videos.
    def fetch_held(min_id, per_page, options = {})
      options = {
        :limit => per_page,
      }.merge(options)
      video_ids = self.held_video_ids.rangebyscore(min_id || "-INF", "INF", options)
      video_ids.map {|id| Video.find_by_id(id) }
    end

    # Deliver pending callbacks to the clients.
    def process_callback_queue
      QueueProcessor.work_off_queue
    end
    alias_method :process_notification_queue, :process_callback_queue

  end

  def initialize(new_attrs = {})
    self.id = new_attrs[:id]
    # Load existing data if we have an id.
    self.temp_attrs = self.id ? self.attrs.clone : {}
    # Keys always come back from redis as strings, not symbols.
    self.temp_attrs = HashWithIndifferentAccess.new(self.temp_attrs)
    # Deserialize nested hashes.
    self.nested_attributes.each do |name|
      val = self.temp_attrs[name]
      self.temp_attrs[name] = val.nil? ? nil : JSON.parse(val)
    end
    self.temp_attrs.merge!(new_attrs.slice(*self.attribute_names))
  end

  self.attribute_names.each do |name|
    # Define reader methods for attributes.
    define_method name do
      self.temp_attrs[name]
    end

    # Define writer methods for attributes.
    define_method "#{name}=" do |value|
      self.temp_attrs[name] = value
    end
  end

  def created_at_time
    n = self.temp_attrs[:created_at]
    return nil if ! n
    Time.at(n.to_i)
  end

  # Bracket indexing is used by ActiveRecord.
  def [](name)
    self.temp_attrs[name]
  end

  # Used by ActiveRecord.
  def destroyed?
    false  # TODO: Not currently tracking when we delete an object.
  end

  # Used by ActiveRecord.
  def new_record?
    self.id.nil?
  end

  def save
    write_attrs
    enqueue
    true
  end

  def delete
    return false unless self.id
    redis.multi do
      dequeue_non_atomically
      self.class.redis_objects.each do |key,opts|
        # Skip class-level keys.
        next if opts[:global]

        redis.del(redis_field_key(key))
      end
    end
    true
  end

  # Currently, there's nothing extra to do besides what's done in #delete.
  alias_method :destroy, :delete

  def write_attrs
    self.id ||= generate_id
    self.temp_attrs[:id] = self.id
    self.temp_attrs[:created_at] ||= Time.now.utc.to_i

    attrs_to_write = self.temp_attrs.dup
    # Serialize nested hashes.
    self.nested_attributes.each do |name|
      val = attrs_to_write[name]
      attrs_to_write[name] = val.to_json if ! val.nil?
    end

    self.attrs.bulk_set(attrs_to_write)
  end

  # Add to the appropriate queue based on status.
  def enqueue
    case self.temp_attrs[:status].to_s
    when 'pending'
      redis.multi do
        redis.zadd(self.class.pending_video_ids.key, self.id, self.id)
        redis.zrem(self.class.held_video_ids.key, self.id)
      end
    when 'held'
      redis.multi do
        redis.zadd(self.class.held_video_ids.key, self.id, self.id)
        redis.zrem(self.class.pending_video_ids.key, self.id)
      end
    else
      redis.multi do
        dequeue_non_atomically
      end
    end
  end

  # Remove from all queues.
  def dequeue_non_atomically
    redis.zrem(self.class.pending_video_ids.key, self.id)
    redis.zrem(self.class.held_video_ids.key, self.id)
  end

  def dequeue
    redis.pipelined do
      dequeue_non_atomically
    end
  end

  def attribute_names
    self.class.attribute_names
  end

  #############################################################################
  # Votes

  def create_vote(decision, params, worker)
    vote = Vote.find_by_worker_id_and_video_id(worker.id, self.id)
    if ! vote
      vote = Vote.new
      vote.worker = worker
      vote.video = self
      vote.taskname = TASK_NAME
      vote.weight = 1 + 4 * worker.clearance.to_i
    end

    vote.decision = case decision.to_s
    when 'pass', 'true', 'yes'
      'pass'
    when 'fail', 'false', 'no'
      'fail'
    end

    vote.video_approval_params = params
    vote.save
    self.tally_votes(vote)
  end

  def tally_votes(vote)
    minimum_votes = Settings.get('min_votes') || 5   # min number needed to approve
    maximum_votes = Settings.get('max_votes') || 10  # auto-rejection if consensus hasn't been reached by this many votes
    approval_ratio = Settings.get('approval_percentage') || 80
    rejection_ratio = Settings.get('reject_percentage') || 60

    all = task_votes.map { |v| v.weight.to_i }.reduce(:+)
    pass = pass_votes.map { |v| v.weight.to_i }.reduce(:+)
    fail = fail_votes.map { |v| v.weight.to_i }.reduce(:+)

    if all >= minimum_votes.to_i
      if (pass.to_f / all.to_f) * 100 >= approval_ratio.to_i
        mark_passed(vote)
      elsif ((fail.to_f / all.to_f) * 100 >= rejection_ratio.to_i)
        mark_failed(vote)
      elsif all >= maximum_votes.to_i
        mark_unclear(vote)
      else
        # No decision yet. Wait for more votes...
      end
    end
  end

  def task_votes
    Vote.where(:video_id => self.id, :taskname => TASK_NAME)
  end

  def pass_votes
    task_votes.where(:decision => 'pass')
  end

  def fail_votes
    task_votes.where(:decision => 'fail')
  end

  def mark_passed(vote)
    self.tasks_passed << TASK_NAME
    self.pass_votes.update_all(:correct => :yes)
    self.fail_votes.update_all(:correct => :no)
    self.after_task_completion(vote)
  end

  def mark_failed(vote)
    self.tasks_failed << TASK_NAME
    self.pass_votes.update_all(:correct => :no)
    self.fail_votes.update_all(:correct => :yes)
    self.after_task_completion(vote)
  end

  def mark_unclear(vote)
    self.tasks_undecided << TASK_NAME
    self.task_votes.update_all(:correct => :unknown)
    self.after_task_completion(vote)
  end

  def after_task_completion(vote)
    # There is currently only 1 video task, so if we're here, we've completed
    # all tasks.
    self.status = 'delivering'
    self.save
    VideoCallbackWorker.perform_async(vote.id)
  end

  # POST callback.  On failure, raises.
  def deliver_callback(vote)
    passed = self.tasks_passed.members
    failed = self.tasks_failed.members
    undecided = self.tasks_undecided.members
    begin
      body = self.passthru || {}
      body.merge!({
        :url => self.url,
        :passed => passed,
        :failed => failed,
        :undecided => undecided,
      })
      %w[ratings message_to_user tags reject_reason_id].each do |name|
        if vote.video_approval_params[name]
          body[name] = vote.video_approval_params[name]
        end
      end
      response = HTTParty.post(self.callback_url, :body => body)
      if (200..299).include?(response.code)
        self.status = 'completed'
        self.save
        Peanut::GeneralLog.log_event "Callback succeeded: #{self.callback_url} #{body}", :callback
        true
      else
        Peanut::GeneralLog.log_error "Callback failed with HTTP code #{response.code}: #{self.callback_url}", :callback
        raise "Non-success status code returned: #{response.code}"
      end
    rescue Exception => e
      Peanut::GeneralLog.log_error "Callback failed: #{self.callback_url}: #{e.class}: #{e.message}", :callback
      raise e
    end
  end


  private

  def generate_id
    self.class.last_video_id.increment
  end

end
