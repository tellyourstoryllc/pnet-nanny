module Peanut
  module Redis
    module Helpers
      # Set keys in bulk, takes a hash of field/values {'field1' => 'val1'}.
      # Redis: HMSET
      #
      # Similar to HashKey#bulk_set from redis-objects but works with
      # `redis.multi` and `redis.pipeline`. Currently does not do marshalling.
      def redis_hash_key_bulk_set(key, *args)
        raise ArgumentError, "Argument to bulk_set must be hash of key/value pairs" unless args.last.is_a?(::Hash)
        redis.hmset(key, *args.last.inject([]){ |arr,kv|
          arr + [kv[0], kv[1]]
        })
      end
    end
  end
end
