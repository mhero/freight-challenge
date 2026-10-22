# Test-only loader that turns the bundled sample feed (db/feeds/response.json) into domain objects.
# It is replaced by the real feed adapter in Step 04.
module SampleFeed
  PATH = Rails.root.join("db/feeds/response.json")

  module_function

  def payload
    @payload ||= JSON.parse(PATH.read, decimal_class: BigDecimal)
  end

  def sailings
    payload.fetch("sailings").map do |row|
      Freight::Sailing.new(
        code: row["sailing_code"],
        origin: row["origin_port"],
        destination: row["destination_port"],
        departure_date: Date.iso8601(row["departure_date"]),
        arrival_date: Date.iso8601(row["arrival_date"])
      )
    end
  end

  def rates
    payload.fetch("rates").map do |row|
      Freight::Rate.new(sailing_code: row["sailing_code"], price: Freight::Money.parse(row["rate"], row["rate_currency"]))
    end
  end

  def exchange_rates
    table = payload.fetch("exchange_rates").to_h do |date, rates|
      [ Date.iso8601(date), rates.to_h { |code, rate| [ Freight::Currency.new(code), rate ] } ]
    end
    Freight::ExchangeRates.new(table)
  end

  def catalogue
    Freight::CatalogueBuilder.new(exchange_rates).build(sailings: sailings, rates: rates)
  end
end
