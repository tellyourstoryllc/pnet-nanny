class AddTaskNameToVotesEnum < ActiveRecord::Migration
  def up
    change_column :votes, :taskname, "ENUM('nudity','video_approval')", :default => nil
  end

  def down
    change_column :votes, :taskname, "ENUM('nudity')", :default => nil
  end
end
