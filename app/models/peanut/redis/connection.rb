# A Redis backed key-value store
require 'redis'

module Peanut
  module Redis
    module Connection

      class Pool

        @@connections = {}
        @@class_connections = {}

        # Hash of class => string
        @@namespaces = {}

        cattr_accessor :connections
        cattr_accessor :class_connections
        cattr_accessor :namespaces
        cattr_accessor :redis_config

        begin
          @@redis_config = YAML.load_file("#{Rails.root}/config/redis.yml")
        rescue Exception => err
          @@redis_config = nil
          Rails.logger.warn "Error loading redis.yml: #{err.to_s}"
        end

        def self.klass_key_for(klass)
          ActiveSupport::Inflector.underscore(klass.to_s)
        end

        def self.config_for(klass)
          unless klass == Object
            result = @@redis_config[self.klass_key_for(klass)] || self.config_for(klass.superclass)
            result
          end
        end

        def self.reconnect
          self.connections.each do |config, connection|
            connection.client.reconnect
          end
        end

      end

      # Load redis.yml config file. It should look something like this:
      #
      # default:
      #    host: 127.0.0.1
      #    db: 0

      def self.connection_for(object)
        klass = object.is_a?(Class) ? object : object.class   

        if redis_params = Pool.config_for(klass) || Pool.redis_config[Rails.env]
          host = redis_params['host']
          port = redis_params['port'] || 6379
          db = redis_params['db']
          config = "#{host}:#{port}:#{db}"
        else
          config = nil
        end

        unless Pool.class_connections[klass]
          Rails.logger.info("Using redis server #{config} => #{Pool.klass_key_for(klass)} (#{klass.to_s})")
          Pool.class_connections[klass] = config
        end

        unless config.nil? or Pool.connections[config] 
          begin
            if new_redis = ::Redis.new({:db=>db, :host=>host, :port=>port}) and new_redis.info
              Pool.connections[config] = new_redis
            end
          rescue Errno::ECONNREFUSED
            Rails.logger.error("Error connecting to redis server: #{host}:#{port} db:#{db}")              
          end          
        end

        if config and conn = Pool.connections[config]
          conn
        elsif config
          new_conn = ::Redis.new({:db=>db, :host=>host, :port=>port})
          Pool.connections[config] = new_conn
          new_conn
        else
          ::Redis.current
        end

      end

      def self.reset_connection_for(klass)
        # tbd
      end

      def self.namespace_for(object)
        klass = object.is_a?(Class) ? object : object.class        
        Pool.namespaces[klass] ||= klass.ancestors.include?(ActiveRecord::Base) ? klass.table_name : ActiveSupport::Inflector.underscore(klass.to_s)
      end

      def self.included(klass)
        klass.extend ClassMethods
      end

      module ClassMethods
        def redis
          Peanut::Redis::Connection.connection_for(self)
        end
      end

    end
  end
end