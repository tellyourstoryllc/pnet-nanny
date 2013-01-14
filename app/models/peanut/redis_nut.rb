# An item that is stored only in Redis- i.e., none of the attributes are stored in SQL.

require 'peanut/redis/connection'

class Peanut::RedisNut < Object
  
  extend ActiveModel::Callbacks
  define_model_callbacks :save, :create, :destroy

  include ::Peanut::Redis::Connection
  include ::Peanut::Redis::Attributes  
  include ::Peanut::ErrorLog

  redis_attr :created_at

  attr_accessor :id
  class_attribute :json_object_type_name

  @expire_duration = nil

  class << self
    attr_accessor :expire_duration

    def json_object_type
      self.json_object_type_name || self.name.downcase.gsub(':','_')
    end

    #--------------------------------------------------------------------------
    # class methods
    def find(id)
      if id.is_a?(Array)
        id.map { |i| self.find(i) }
      elsif id
        obj = self.new(:id=>id.to_s)
        v = obj.redis_attributes.contents
        v.empty? ? nil : obj
      end
    end

    def find_by_id(id)
      self.find(id)
    end

    def find_or_create_by_id(id)
      if id.is_a?(Array)
        id.map { |i| self.find_or_create_by_id(i) }
      elsif id
        self.new(:id=>id.to_s)
      end
    end

    # This searches ALL redis keys. Should be used *very* sparingly.    
    def all
      prefix = ::Peanut::Redis::Connection.namespace_for(self)
      pattern = /#{prefix}:([^:]*)/i
      ids = self.redis.keys("#{prefix}*").map { |key| key =~ pattern; $1 }.reject { |id| id.nil? }
      self.find_or_create_by_id(ids)
    end

  end

  #----------------------------------------------------------------------------
  # instance methods

  def initialize(values=nil)
    values.each do |k,v|
      @id = v if k.to_sym == :id
      self.redis_attributes[k] = v if attribute_names.include?(k.to_s)
    end if values
    self.created_at ||= Time.now.utc
    self
  end

  def attributes
    self.redis_attributes.values.merge({:id=>self.id})
  end

  alias_method :attribute_names, :redis_attribute_names

  def ==(other_record)
    if other_record and other_record.kind_of?(self.class)
      self.id == other_record.id
    else
      false
    end
  end

  def to_s
    "#{super}:#{self.id}:#{attributes}"
  end

  def as_json(options={})
    self.attributes.reject { |k,v| k =~ /^_/ }.merge({'object_type' => options[:object_type] || self.class.json_object_type })
  end

  def save_or_create
    @id ||= self._generate_id
    self.redis_attributes[:created_at] ||= Time.now.utc if self.respond_to?(:created_at)
    self.redis_attributes.save

    duration = nil  # default, does not expire
    if self.respond_to?(:expires_at) and expires = self.expires_at and delta = expires - Time.now and delta > 0
      duration ||= delta
    end

    duration ||= self.expire_duration if self.respond_to?(:expire_duration)
    duration ||= self.class.expire_duration    
    self.redis_attributes.connection.expire(self.redis_attributes.target_key, duration.to_i) if duration 
    self
  end

  def save
    run_callbacks(:save) do
      self.save_or_create
    end
  end

  def create
    run_callbacks(:create) do
      self.save_or_create
    end
  end  

  def fields
    self.attribute_names
  end

  def delete
    destroy
  end

  def destroy
    run_callbacks(:destroy) do
      self.redis_attributes.clear!
    end
    nil
  end

  def memoize(value=nil, &block)
    # Memoize doesn't do anything for redis objects
    yield if value.nil? and block_given?
  end

  #----------------------------------------------------------------------------  
  # hack for making attributes act like activerecord objects
  def method_missing(method_name, *args)

    if method_name == :[]
      redis_attributes[args.first.to_sym]
    elsif method_name == :[]=
      redis_attributes[args.first.to_sym] = args.last
    elsif (attribute_names.include? method_name)
      redis_attributes[method_name.to_sym]
      # hack!
    elsif (method_without_equals = method_name.to_s.gsub('=','').to_sym) && (redis_attribute_names.include? method_without_equals)
      redis_attributes[method_without_equals] = args.last
    else
      super(method_name, *args)
    end    
  end

  #----------------------------------------------------------------------------

  def _generate_id
    self.redis_attributes.connection.incr("id_generator_#{ActiveSupport::Inflector.underscore(self.class)}").to_s(36)
  end

  def new_record?
    @id.nil?
  end

end
