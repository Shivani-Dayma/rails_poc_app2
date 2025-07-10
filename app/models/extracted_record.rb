class ExtractedRecord < ApplicationRecord
  belongs_to :general_file
  scope :active, -> { where(deleted_at: nil) }
end