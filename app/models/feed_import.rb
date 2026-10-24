# One processed (or failed) feed. Rows created by an import point back to it.
class FeedImport < ApplicationRecord
  STATUSES = %w[ processing completed failed ].freeze

  has_many :import_issues

  validates :source, :checksum, :raw_payload, :started_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :completed, -> { where(status: "completed") }
end
