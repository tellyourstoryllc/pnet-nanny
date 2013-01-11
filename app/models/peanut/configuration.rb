# A class used for storing and saving configuration settings.
# Looks in redis store first. If not found, try to load from configuration file.

class Peanut::Configuration < Peanut::RedisNut
  cattr_accessor :filename
  cattr_accessor :cache_duration

  class << self

    def singleton
      @@singleton ||= self.find_or_create_by_id(:configuration)
    end

    def get(key)
      self.singleton.get(key)
    end

    def set(key, value)
      self.singleton.set(key, value)
    end

    def reset(key)
      self.singleton.set(key, nil)
      self.singleton.get(key)
    end

    def all
      self.singleton.all_attributes
    end

  end  

  def get(key)
    duration = self.class.cache_duration || 10
    PCache.capture(:key=>"#{self.class}_#{key}", :duration=>duration) do
      self.redis_attributes[key.to_s] || self.file_attributes[key.to_s]
    end
  end

  def set(key, value)
    PCache.invalidate("#{self.class}_#{key}")
    self.redis_attributes[key.to_s] = value
    self.save
    value
  end

  def all_attributes
    file_attributes.merge(redis_attributes.values.stringify_keys)
  end

  def file_attributes
    @attributes ||= begin
      if filename = self.class.filename
        begin
          yaml = YAML.load_file("#{Rails.root}/config/#{filename}")
          yaml[Rails.env] || {}
        rescue Exception => err
          Rails.logger.error "Unable to open load: #{Rails.root}/config/#{filename}"
          {}
        end
      else
        {}
      end
    end
  end

end