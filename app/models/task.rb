class Task

  @@config = YAML.load_file("#{Rails.root}/config/tasks.yml")
  @@tasks = {}

  include ::Peanut::Redis::Objects

  list :pending_photo_ids
  value :hit_id
  value :hittype_id

  value :max_hit_photo_id   # The largest photo ID that has been assigned to a Turk

  attr_accessor :id, :view, :hit_properties, :hittype_properties, :instructions, :description
  attr_accessor :photos_per_hit, :queue_delay

  def name
    self.id
  end

  class << self

    def find(name)
      name = name.to_s
      if task = @@tasks[name]
        task
      elsif attributes = @@config[name]
        t = self.new
        t.id = name
        t.description = attributes['description']
        t.view = attributes['view']
        t.hit_properties = attributes['hit']
        t.hittype_properties = attributes['hittype']
        t.photos_per_hit = attributes['photos_per_hit']
        t.queue_delay = attributes['queue_delay']
        t.instructions = File.read("#{Rails.root}/config/mturk/#{attributes['instructions']}")
        @@tasks[name] = t
      end
    end

    def all
      @@config.each { |k,v| self.find(k) }
      @@tasks.values
    end

    def first
      self.all.first
    end

    alias_method :default, :first
    
  end

  alias_method :raw_hittype_id, :hittype_id

  def hittype_id
    self.raw_hittype_id ||= begin
      props = Amazon::Util::DataReader.load("#{Rails.root}/config/mturk/#{self.hittype_properties}", :Properties)
      hittype = Turkey.adapter.registerHITType(props)
      hittype[:HITTypeId]
    end
  end

  def reset_hit
    self.hit_id = nil
  end

  def create_hit(min_photo_id=0)
    question = <<-TEXT
<?xml version="1.0"?>
<ExternalQuestion xmlns="http://mechanicalturk.amazonaws.com/AWSMechanicalTurkDataSchemas/2006-07-14/ExternalQuestion.xsd">
<ExternalURL>http://nanny.perceptualnet.com/mturk/review?task=#{self.id}&min_id=#{min_photo_id}</ExternalURL> 
<FrameHeight>800</FrameHeight>
</ExternalQuestion>  
    TEXT
    props = Amazon::Util::DataReader.load("#{Rails.root}/config/mturk/#{self.hit_properties}", :Properties)
    props[:HITTypeId] = self.hit_type_id
    props[:Question] = question
    hit = Turkey.adapter.createHIT(props)
    self.hit_id = hit[:HITId]
    UseLog.increment("createHIT")
  end

  def last_hit_id
    self.hit_id
  end

  def hit_url
    if self.hittype_id
      if Turkey.adapter.host =~ /sandbox/
        "http://workersandbox.mturk.com/mturk/preview?groupId=#{self.hittype_id}" # Sandbox Url
      else
        "http://mturk.com/mturk/preview?groupId=#{self.hittype_id}" # Production Url
      end
    end
  end

  def hit_info
    Turkey.adapter.getHIT(:HITId => self.hit_id)
  end

  # This is called by Photo.add_task. Controllers should not call this directly
  def add_photo(photo)
    self.pending_photo_ids << photo.id
  end

  # This is called by Photo.remove_task. Controllers should not call this directly
  def remove_photo(photo)
    self.pending_photo_ids.delete(photo.id)
  end

  # Pick some tasks for worker to review. Returns an array of photos.
  def fetch_assignments(worker, min_id=0, turk_assignmentId=nil)
    foto_ids = self.pending_photo_ids.values
    
    offset=0; x=0
    foto_ids.each do |id|
      if id.to_i > min_id
        offset = x
        break
      else
        x += 1
      end
    end
    
    limit = self.photos_per_hit
    results = []; current_offset = offset
    Photo.find_all_by_id(foto_ids[offset..offset+2*limit]).each do |foto|
      # skip if worker already voted on this
      next if worker.votes_for_photo(foto).map { |vote| vote.taskname }.include?(self.name)
      results << foto
      break if results.size > limit
      current_offset += 1
    end

    # The following bit creates a new hit if needed:

    # Use turk_assignmentId to determine if page is being accessed by a Turkey or not.
    unless turk_assignmentId.nil? or results.empty?
      if self.max_hit_photo_id.nil?
        self.max_hit_photo_id = results.last.id.to_i
      elsif self.max_hit_photo_id < results.last.id.to_i
        # Check if there are enough pending pics for a full additional page
        if foto_ids.size - current_offset > self.photos_per_hit
          self.create_hit(foto_ids[current_offset])
          self.max_hit_photo_id = foto_ids[current_offset + self.photos_per_hit]
        end
      end
    end
  
    results
  end

end