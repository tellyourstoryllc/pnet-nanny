# pHash: http://www.phash.org
# Installing on linux: https://github.com/mperham/phashion/pull/9

require 'phashion'

class Fingerprint < Peanut::ActivePeanut::Base
  include Peanut::Redis::Attributes

  self.table_name = 'photo_fingerprints'

  include Peanut::Redis::Objects
  redis_attr :task_decisions
  set :photo_ids
  
  class << self
    def lookup(fingerprint_value)
      self.find(:first, :conditions=>["value = :fp", {:fp=>fingerprint_value} ])
    end
  end

  #----------------------------------------------------------------------------
  
  def matches?(other_fingerprint, threshold=15)
    Phashion.hamming_distance(self[:value], other_fingerprint[:value]) < threshold
  end

  def initialize
    super
    self.task_decisions ||= {}
    self
  end

  def save
    self[:created_at] ||= Time.now.utc
    super
  end
  
  def photos
    Photo.find(:all, :conditions=>Photo.conditions_for_find(:fingerprint=>self[:value]))
  end
  
end
