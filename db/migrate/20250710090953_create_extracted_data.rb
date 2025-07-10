class CreateExtractedData < ActiveRecord::Migration[7.1]
  def change
    create_table :extracted_records do |t|
      t.references :general_file, null: false, foreign_key: true
      t.jsonb :data
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
