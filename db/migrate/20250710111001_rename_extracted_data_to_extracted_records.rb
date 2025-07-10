class RenameExtractedDataToExtractedRecords < ActiveRecord::Migration[7.1]
  def change
    rename_table :extracted_data, :extracted_records
  end
end
