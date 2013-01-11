require 'redis/objects'

module Peanut
  module Redis
    module Objects

      def destroy_redis_objects
        self.class.redis_objects.each do |key,opts|
          self.redis.del(redis_field_key(key))
        end
      end

      def self.included(klass)
        # unless klass.superclass and klass.superclass.included_modules.include?(self)
          klass.class_eval "include ::Redis::Objects"
          klass.class_eval "before_destroy :destroy_redis_objects" if klass.ancestors.include?(ActiveRecord::Base) || klass.ancestors.include?(Peanut::RedisNut)
          klass.send(:redis=, Peanut::Redis::Connection.connection_for(klass))
        # else
        #   Rails.logger.info "\nSuperclass #{klass.superclass} of #{klass} already includes #{self}!"
        # end
      end
    end
  end
end