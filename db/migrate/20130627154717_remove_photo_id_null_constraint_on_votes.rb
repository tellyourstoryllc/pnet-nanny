class RemovePhotoIdNullConstraintOnVotes < ActiveRecord::Migration
  def up
    execute "alter table `votes` modify column `photo_id` bigint(20) unsigned DEFAULT NULL"
  end

  def down
    execute "alter table `votes` modify column `photo_id` bigint(20) unsigned NOT NULL"
  end
end
