# A search that had no answer yet. Fulfilled when a later import makes it answerable.
class SavedSearch < ApplicationRecord
  STATUSES = %w[ pending fulfilled ].freeze

  belongs_to :fulfilled_import, class_name: "FeedImport", optional: true
  has_one :fulfillment_event

  validates :origin_port, :destination_port, :criterion, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }

  # Deduplicated by origin, destination and criterion among pending searches.
  def self.record_unfulfilled!(origin:, destination:, criterion:)
    attributes = { origin_port: origin, destination_port: destination, criterion: criterion }
    pending.find_by(attributes) || create!(attributes)
  rescue ActiveRecord::RecordNotUnique
    pending.find_by!(attributes)
  end
end
