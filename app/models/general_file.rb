class GeneralFile < ApplicationRecord
  has_one_attached :file
  has_many :extracted_records, dependent: :destroy
  scope :active, -> { where(deleted_at: nil) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end
end
