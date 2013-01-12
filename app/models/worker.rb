class Worker < Peanut::ActivePeanut::Base    

  include Peanut::Redis::Attributes
  include Peanut::Redis::Objects

  attr_accessible :turk_id, :username, :password, :clearance, :weight, :token, :status
  attr_accessible :created_at, :creating_ip
  attr_accessible :total_votes, :rating

  redis_attr :correct_votes, :incorrect_votes
  list :recent_votes, :maxlength=>1000, :marshal=>true

  # ---------------------------------------------------------------------------
  def save
    self.token ||= Peanut::Toolkit.rand_string(Time.now.utc)[0..15]
    self.clearance ||= 1
    self.weight ||= 1
    super
  end

  def registered?
    self.username and self.password
  end

  def create_vote(decision, task_name, photo)
    photo.create_vote(decision, task_name, self)
  end

  def votes_for_photo(photo)
    pid = case photo
    when String, Fixnum
      photo
    when Photo
      photo.id
    end
    self.votes.where('photo_id = ?', pid)
  end

  def votes
    Vote.where('worker_id = ?', self.id) if self.id
  end

  def update_rating
    all_votes = votes.where("correct = 'yes' or correct = 'no'").count    
    bad_reject_votes = votes.where("decision='fail' and correct='no'").count
    bad_approve_votes = votes.where("decision='pass' and correct='no'").count

    if all_votes < 10 # Noob worker
      score = 1
    else
      # Extra penalty for erroneous approvals!
      score = 100 - (((bad_reject_votes.to_f + 3*bad_approve_votes.to_f) / all_votes.to_f) * 100).round
      score = 0 if score < 0
    end

    self.correct_votes = all_votes - bad_reject_votes - bad_approve_votes
    self.total_votes = all_votes
    self.rating = score
    self.save

    self.rating
  end

end