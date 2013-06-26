require 'peanut/redis/connection'

class Peanut::RedisOnly
  include ::Peanut::Redis::Connection

  # For Notifications
  def self.find_by_id(id)
    new(:id => id.to_s)
  end
end
