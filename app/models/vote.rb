class Vote < Peanut::ActivePeanut::Base
  include Peanut::Redis::Attributes

  self.table_name = 'votes'
  attr_accessible :worker_id, :photo_id, :taskname, :decision, :weight
  attr_accessible :status # pending, correct, incorrect

  # Hash of video approval arguments.  e.g. ratings, custom message, etc.
  redis_attr :video_approval_params

  belongs_to :worker, :class_name=>'Worker', :foreign_key=>'worker_id'
  belongs_to :photo, :class_name=>'Photo', :foreign_key=>'photo_id'
  belongs_to :video

  def task
    @task ||= Task.find(self.taskname)
  end

  # Since Video isn't an ActiveRecord model, the default association method
  # doesn't work.
  def video
    @video ||= Video.find(self.video_id)
  end

end