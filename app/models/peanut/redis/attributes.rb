# Store record attributes in redis instead of mysql.
# The attributes are all stored in a single hash.
require 'redis'

module Peanut
  module Redis
    module Attributes

      class Adapter

        def initialize(obj)
          @target = obj
        end

        def connection
          Connection.connection_for(@target)
        end

        def target_key
          "#{Connection.namespace_for(@target)}:#{@target.id}" if @target.id
        end

        def fetch_data

          key = self.target_key
          redis = key ? self.connection : nil
          
          if redis and key and value = redis.get(key) 
            Marshal.load(value)
          elsif redis.nil? and key
            raise "Cannot load redis attributes for #{key} from #{self.connection}"
          end
        end

        def [](key)
          self.contents[key.to_sym]
        end

        def []=(key, value)
          @contents ||= fetch_data || {}

          if value
            @contents[key.to_sym] = value
          else
            @contents.delete(key.to_sym)
          end
        end

        def contents
          @contents ||= fetch_data || {}
        end

        def values
          self.contents
        end
        
        def save
          key = self.target_key
          redis = key ? self.connection : nil

          if redis and key
            stuff = self.contents
            stuff.empty? ? redis.del(key) : redis.set(key, Marshal.dump(stuff))
            @target.memoize if @target.respond_to?(:memoize, true)
            
          elsif redis.nil? and key
            raise "Cannot save redis attributes for #{@target.class}:#{@target.id ? @target.id : 'nil'}. No redis connection!"
          else
             # no id for object yet- just let the data hang out in @contents
          end
        end
        
        def clear!
          if target_key and redis = self.connection
            redis.del(target_key)
            @contents = {}
          end
        end
        
      end
      # /Adapter

      def redis_attributes
        @my_attributes ||= Peanut::Redis::Attributes::Adapter.new(self)
      end

      def redis_attribute_names
        self.class.redis_attribute_names
      end

      def save_redis_attributes
        redis_attributes.save
      end

      def destroy_redis_attributes
        redis_attributes.clear!
      end

      def self.included(klass)
        klass.extend(ClassMethods)
      end

      module ClassMethods

        def redis_attribute_names
          if superclass.respond_to?(:redis_attribute_names)
            @attribute_names ||= ([] + superclass.redis_attribute_names)
          else
            @attribute_names ||= []
          end
        end

        def redis_attr(*names)

          if redis_attribute_names.empty? and (self.ancestors.include?(ActiveRecord::Base) || self.ancestors.include?(Peanut::RedisNut))
            class_eval "after_save :save_redis_attributes"
            class_eval "before_destroy :destroy_redis_attributes"
          end

          [names].flatten.each do |name|
            class_eval <<-POOP
              def #{name}
                self.redis_attributes[:#{name}]
              end

              def #{name}=(value)
                self.redis_attributes[:#{name}] = value
              end

            POOP
            
            redis_attribute_names << name.to_s
          end
          
        end
      end
            
    end
  end
end