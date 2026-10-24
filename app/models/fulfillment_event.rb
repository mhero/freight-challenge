class FulfillmentEvent < ApplicationRecord
  belongs_to :saved_search
  belongs_to :feed_import

  scope :unacknowledged, -> { where(acknowledged_at: nil) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }
end
