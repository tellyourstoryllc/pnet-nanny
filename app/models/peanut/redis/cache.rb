# A redis-backed memcached type thingy.

require 'timeout'

module Peanut
  module Redis
    class Cache < ::Peanut::RedisNut

      redis_attr :value, :created_at, :expires_at

      MAX_OBJ_SIZE = 900000
      @@logger = Rails.logger

      # Captures the output of the given block and caches it for a duration of time.
      # e.g.,
      # @slow_query_result = Peanut::Redis::Cache.capture do
      #   items = Item.find(:all, conditions)
      #   items.map { |i| i.booger }
      # end
      def self.capture(options={}, &block)
        if block_given?
          options[:duration] ||= 888

          unless key = options[:key]
            key = ::Peanut::Toolkit.hash(caller.join)
          end

          if value = get(key, options.merge(:max_age=>options[:duration])) and !options[:no_cache]
            # decode nil
            value = nil if value == '__nilz__'
            return value
          else
            value = yield
            sval = value.nil? ? '__nilz__' : value

            put(key, sval, options) unless options[:no_cache]
            return value
          end
        end
      end

      def self.put(the_key, obj, options={})

        the_key = generate_redis_key(the_key, options)

        log "#{self.name} put #{obj.class} object at key: #{the_key}" do
          begin
            value = Marshal.dump(obj)

            if value.length > MAX_OBJ_SIZE
              log "Too big for #{self.name}: #{the_key} size: #{value.length}"
              return obj 
            end

            options[:duration] ||= 3600
            expires = options[:expires_at] || Time.now + options[:duration]

            log "Save to #{self.name}: #{the_key} size: #{value.length} expires: #{expires}"
            self.new(:id=>the_key, :value=>value, :expires_at=>expires.utc).save

            obj
          rescue Exception => ex
            log "#{self.name} exception in self.put: #{ex}"
            nil
          end
        end
      end

      def self.get(the_key, options={})

        the_key = generate_redis_key(the_key, options)

        log "#{self.name} get #{the_key}" do

          now = Time.now.utc

          if record = self.find(the_key)

            if record.expires_at and record.expires_at < now
              log "#{self.name} hit: #{the_key}, but EXPIRED"
              record.delete
              return nil
            elsif options[:max_age] && (record.created_at < now - options[:max_age])
              record.delete
              log "#{self.name} hit: #{the_key}, but TOO OLD"
              return nil
            else
              begin
                log "#{self.name} hit: #{the_key}"
                Marshal.load(record.value)

              rescue Exception => err
                log "#{self.name} bad data: #{the_key}, #{err}, #{err.class}"
                record.delete
                nil
              end
            end
          end
        end
      end

      def self.invalidate(the_key, options={})
        log("#{self.name} invalidate #{the_key}") do
          if item = find(generate_redis_key(the_key, options))
            item.delete
          end
        end
      end

      # "Single exclusion" - if this block is being run elsewhere, skip it. (Not a mutex, since it doesn't block)
      def self.singlex(options={}, &block)
        if block_given?
          unless key = options[:key]
            key = ::Peanut::Toolkit.hash(caller.join)
          end

          unless get(key)
            put(key, true, options)
            value = yield
            invalidate(key)
            return value
          end
        end
      end      

      # Shitty mutex
      def self.mutex(options={}, &block)
        if block_given?
          unless key = options[:key]
            key = ::Peanut::Toolkit.hash(caller.join)
          end

          timeout(options[:timeout] || 600) do
            wait = 0.1
            while get(key) or put(key, true, options).nil?
              wait = wait * 1.1
              sleep(wait)
            end        
          end

          begin
            value = yield
            invalidate(key)
          rescue Exception => err
            invalidate(key)
            raise $!  
          end
          return value
        end
      end      

      private 

      def self.generate_redis_key(the_key, options={})
        the_key = canonize(the_key)
        the_key = Peanut::Toolkit.hash(options[:vary])[0..31] + the_key if options[:vary]
        the_key
      end

      def self.canonize(the_key)
        the_key.to_s[0..254]
      end

      def self.log(info)
        if block_given?
          if @@logger and @@logger.debug?
            result = nil
            seconds = Benchmark.realtime { result = yield }
            @@logger.debug "[PEANUT CACHE] #{info}: (#{(seconds * 1000000).round} us)"
            result
          else
            yield
          end
        else
          @@logger.debug "[PEANUT CACHE] #{info}"
          nil
        end
      end

    end
  end
end