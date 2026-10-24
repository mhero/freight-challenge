# EUR-based daily rate, currency stored in lowercase ("usd").
class ExchangeRate < ApplicationRecord
  belongs_to :import, class_name: "FeedImport"

  validates :date, :currency, :rate, presence: true

  def self.table_for(dates)
    table = where(date: dates).each_with_object({}) do |exchange_rate, result|
      (result[exchange_rate.date] ||= {})[exchange_rate.currency] = exchange_rate.rate
    end
    Freight::ExchangeRates.new(table)
  end
end
