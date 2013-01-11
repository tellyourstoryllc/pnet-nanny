require 'peanut/redis/connection'

module Peanut
  module Redis
    module List

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def redis_list(key, max_length=nil)
          self.class_eval %{
            def #{key}
              @#{key}_list_adapter ||= Peanut::Redis::List::Adapter.new(self,:#{key}#{','+max_length.to_s if max_length})
            end
            }, __FILE__, __LINE__
        end

        def redis_class_list(key, max_length=nil)
          self.class_eval %{
            def self.#{key}
              @@#{key}_list_adapter ||= Peanut::Redis::List::Adapter.new(self,:class_#{key}#{','+max_length.to_s if max_length})
            end
            }, __FILE__, __LINE__
        end
      end

      class Adapter

        def initialize(obj, key, max_length=nil)
          @target = obj
          @key = key
          @max = max_length
        end

        def redis
          Peanut::Redis::Connection.connection_for(@target)
        end

        alias_method :connection, :redis

        def redis_key
          @redis_key ||= "#{Peanut::Redis::Connection.namespace_for(@target)}_list_#{@key}#{@target.id if @target.respond_to?(:id)}"
        end

        def lpush(obj)
          redis.lpush(redis_key, Marshal.dump(obj))
          redis.ltrim(redis_key, 0, @max-1) if @max
          obj
        end

        def rpush(obj)
          redis.rpush(redis_key, Marshal.dump(obj))
          redis.ltrim(redis_key, -@max, -1) if @max
          obj
        end

        def multi_lpush(*array)
          array.flatten.reverse_each { |obj| lpush(obj) }
          array
        end

        def multi_rpush(*array)
          array.flatten.each { |obj| rpush(obj) }
          array
        end

        def [](arg)
          case arg
          when Range
            if els = redis.lrange(redis_key, arg.first, arg.last)
              els.map { |el| Marshal.load(el) }
            else
              []
            end
          when Integer
            if el = redis.lindex(redis_key, arg)
              Marshal.load(el)
            end
          end
        end

        def lpop
          if value = redis.lpop(redis_key)
            Marshal.load(value)
          end
        end

        def rpop
          if value = redis.rpop(redis_key)
            Marshal.load(value)
          end
        end

      # Pop n elements from the left side of the list. Returns empty array if nothing left to pop.
      def multi_lpop(n=1)
        if values = redis.lrange(redis_key, 0, n-1)
          redis.ltrim(redis_key, n, -1)
          values.map { |v| Marshal.load(v) }
        end
      end

        # Pop n elements from the right side of the list. Returns empty array if nothing left to pop.
        def multi_rpop(n=1)
          if values = redis.lrange(redis_key, 0-n, -1)
            redis.ltrim(redis_key, 0, -1-n)
            values.map { |v| Marshal.load(v) }
          end
        end

        def length
          redis.llen(redis_key)
        end

        def empty?
          length == 0
        end

        def contents
          self[0..-1]
        end

        def element_at(index)
          self[index]
        end

        def include?(el)
          self.contents.include?(el)
        end

        def clear!
          redis.del(redis_key)
        end

        alias_method :size, :length
        alias_method :count, :length
        alias_method :enqueue, :multi_lpush
        alias_method :dequeue, :multi_rpop

        def head
          self[-1]
        end

        def tail
          self[0]
        end
      end
    end
  end
end
