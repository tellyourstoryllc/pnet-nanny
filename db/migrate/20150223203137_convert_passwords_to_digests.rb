class ConvertPasswordsToDigests < ActiveRecord::Migration
  def up
    Worker.find_each do |w|
      w.password = w[:password]
      w.save
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
