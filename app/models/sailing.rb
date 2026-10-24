class Sailing < ApplicationRecord
  EFFECTIVE_RATE_JOIN = <<~SQL.squish.freeze
    INNER JOIN rates
      ON rates.sailing_id = sailings.id AND rates.import_id = sailings.last_seen_import_id
  SQL

  belongs_to :first_import, class_name: "FeedImport"
  belongs_to :last_seen_import, class_name: "FeedImport"
  has_many :rates

  validates :sailing_code, :origin_port, :destination_port, :departure_date, :arrival_date, presence: true

  scope :active, -> { where(active: true) }

  # Active sailings leaving `port` that have a rate in the import that last saw them.
  # The rate is returned as rate_amount / rate_currency.
  def self.priced_departures(port, on_or_after: nil)
    scope = active.where(origin_port: port)
    scope = scope.where(departure_date: on_or_after..) if on_or_after
    scope
      .joins(EFFECTIVE_RATE_JOIN)
      .select("sailings.*", "rates.amount AS rate_amount", "rates.currency AS rate_currency")
      .order(:departure_date, :sailing_code)
  end
end
