class CreateGeneralFiles < ActiveRecord::Migration[7.1]
  def change
    create_table :general_files do |t|
      t.string :file_name
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
