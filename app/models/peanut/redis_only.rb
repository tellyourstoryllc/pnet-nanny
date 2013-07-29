require 'peanut/redis/connection'

class Peanut::RedisOnly
  include ::Peanut::Redis::Connection

  # For Notifications
  def self.find_by_id(id)
    if ! redis.exists(redis_field_key('attrs', id))
      raise ActiveRecord::RecordNotFound.new(id)
    end
    new(:id => id.to_s)
  end
end
