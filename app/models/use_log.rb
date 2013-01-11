# The use log is a way of keeping track of user activity. It is stored as name -> counter pairs for
# each day. Names are hierarchically organized for easier digestion of the data.

require 'date'
require 'redis/objects'
require 'redis/counter'

class UseLog < Peanut::ActivePeanut::Base

  include Peanut::Redis::Objects

  SEPARATOR = '/'

  attr_accessible :parent_id, :name, :description

  self.table_name = 'use_log_categories'

  belongs_to :parent, :class_name => 'UseLog', :foreign_key => 'parent_id'
  has_many :children, :class_name => 'UseLog', :foreign_key => 'parent_id'
  has_many :data, :class_name => 'UseLog::Data', :foreign_key => 'category_id'

  # Class methods -------------------------------------------------------------

  class << self
    # Return the category object associated with the given name. (e.g., 'error/login/wrong_password')
    # If the category doesn't exist yet, create a record for it (and its parent categories, if necessary)
    def retrieve_or_create(name)
      pid = 0
      category = nil
      name.split(UseLog::SEPARATOR).each do |subcat|
        catname = subcat[0..49]
        category = UseLog.find(:first, :conditions => ["name = :name and parent_id = :pid", {:name => catname, :pid => pid}])

        if category.nil?
          category = UseLog.new(:name => catname, :parent_id => pid)
          category.save
        end

        pid = category[:id]
      end

      category
    end

    # Finds the category with the given name. Returns nil if not found.
    def retrieve(name)
      pid = 0
      category = nil
      name.split(UseLog::SEPARATOR).each do |subcat|
        catname = subcat[0..49]
        category = UseLog.find(:first, :conditions => ["name = :name and parent_id = :pid", {:name => catname, :pid => pid}])

        return nil if category.nil?
        pid = category[:id]
      end

      category
    end

    # Increments the named category
    def increment(name, options={})
      step = options[:step] || 1
      date = options[:date] || Date.today.to_s

      unless options[:bypass_cache]
        UseLog::Cache.increment(name, date, step)
      else
        log = UseLog.retrieve_or_create(name)
        log.data_for(date).increment(step)
      end
    end

    alias_method :inc, :increment

    def set(name, value, options={})
      date = options[:date] || Date.today.to_s

      log = UseLog.retrieve_or_create(name)
      data = log.data_for(date)
      data[:count] = value
      data.save
    end

    # Finds all data for specified date
    # Returns a two-dimensional array
    def data_for(date)
      UseLog::Data.find_all_by_date(date).collect do |log|
        [log.category, log.count]
      end
    end

    # Fetch the current value of name
    def [](name)
      if cat = self.retrieve(name) and data = cat.data_for(Date.today.to_s)
        data.count
      end
    end

    def flush
      ::UseLog::Cache.flush
    end

  end

  # Instance methods ----------------------------------------------------------

  def data_for(date)
    the_date = self.data.find :first, :conditions => ["date = ?", date]
    the_date = self.data.build({:date => date, :count => 0}) if the_date.nil?
    the_date
  end

  def full_name
    if self[:parent_id] > 0
      "#{parent.full_name}#{UseLog::SEPARATOR}#{self[:name]}"
    else
      self[:name]
    end
  end

  def first_date
    if x = self.data.find(:first, :order=>'date ASC')
      x.date
    end
  end

  def last_date
    if x = self.data.find(:first, :order=>'date DESC')
      x.date
    end
  end

  class Data < Peanut::ActivePeanut::Base
    self.table_name ='use_log_data'

    attr_accessible :category_id, :date, :count
    belongs_to :category, :class_name => '::UseLog', :foreign_key => 'category_id'

    def increment(step=1)
      self[:count] += step 
      self.save
      self[:count]
    end

  end

  class Cache 

    class << self

      @@counters = {}

      def redis
        UseLog.redis
      end

      def flush
        redis.keys("USELOGCACHE*").each do |key|
          poop, name, date = key.split("USELOGCACHE")
          counter = Redis::Counter.new(key, redis)
          UseLog.retrieve_or_create(name).data_for(date).increment(counter.value)
          redis.del(key)
        end
        true
      end

      def increment(name, date, step=1)
        name = name.to_sym
        date = date.to_s
        key = "USELOGCACHE#{name}USELOGCACHE#{date}"
        @@counters[name] ||= {}
        @@counters[name][date] ||= Redis::Counter.new(key, redis)
        @@counters[name][date].increment(step)
      end

    end
  end

end
