class AddEmailToWorkers < ActiveRecord::Migration
  def change
    add_column :workers, :email, :string, null: false
  end
end
