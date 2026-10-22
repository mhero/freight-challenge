# Small builders for domain value objects. Domain specs use plain objects, no database records.
module DomainHelpers
  def money(text, currency)
    Freight::Money.parse(text, currency)
  end

  def build_sailing(code: "ABCD", origin: "CNSHA", destination: "NLRTM", departure: "2022-02-01", arrival: "2022-03-01")
    Freight::Sailing.new(
      code: code,
      origin: origin,
      destination: destination,
      departure_date: Date.iso8601(departure),
      arrival_date: Date.iso8601(arrival)
    )
  end

  def build_rate(code, text, currency)
    Freight::Rate.new(sailing_code: code, price: money(text, currency))
  end

  # build_exchange_rates("2022-02-01" => { "USD" => "1.25" })
  def build_exchange_rates(table = {})
    Freight::ExchangeRates.new(
      table.to_h do |date, rates|
        [ Date.iso8601(date), rates.to_h { |code, rate| [ Freight::Currency.new(code), BigDecimal(rate) ] } ]
      end
    )
  end

  def build_catalogue(sailings, rates, exchange_rates = build_exchange_rates)
    Freight::CatalogueBuilder.new(exchange_rates).build(sailings: sailings, rates: rates)
  end
end

RSpec.configure { |config| config.include DomainHelpers }
