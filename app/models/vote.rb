class Vote < Peanut::ActivePeanut::Base

  self.table_name = 'votes'
  attr_accessible :worker_id, :photo_id, :taskname, :decision, :weight
  attr_accessible :status # pending, correct, incorrect

  belongs_to :worker, :class_name=>'Worker', :foreign_key=>'worker_id'
  belongs_to :photo, :class_name=>'Photo', :foreign_key=>'photo_id'

  def task
    @task ||= Task.find(self.taskname)
  end

end