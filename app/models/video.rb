class Video < Peanut::RedisOnly
  include ::Redis::Objects

  attr_accessor :id, :temp_attrs
  hash_key :attrs

  class_attribute :attribute_names
  self.attribute_names = %w[
    status client_id url passthru callback_url thumbnail_url
    description info_url creator_url ratings reject_reasons
    message_to_user tags
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

    # Pick some videos for worker to review. Returns an array of Videos.
    def fetch_assignments(worker, min_id, per_page, options = {})
      options = {
        :limit => per_page,
      }.merge(options)
      video_ids = self.pending_video_ids.rangebyscore(min_id || "-INF", "INF", options)
      video_ids.map {|id| Video.find_by_id(id) }
    end

    alias_method :find, :find_by_id

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

  def write_attrs
    self.id ||= generate_id
    self.temp_attrs[:id] = self.id
    self.temp_attrs[:created_at] ||= Time.current.to_i

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

  def attribute_names
    self.class.attribute_names
  end


  private

  def generate_id
    self.class.last_video_id.increment
  end

end
