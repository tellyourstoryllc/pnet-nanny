class AddUuidToPhotos < ActiveRecord::Migration
  def change
    add_column :photos, :uuid, :string
  end
end
