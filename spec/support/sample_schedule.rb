# The sailings of response.json priced in EUR with the domain classes.
# Used by unit specs so they need neither the database nor the feed adapter.
module SampleSchedule
  EXCHANGE_RATES = Freight::ExchangeRates.new(
    Date.new(2022, 1, 29) => { "usd" => BigDecimal("1.1138"), "jpy" => BigDecimal("130.85") },
    Date.new(2022, 1, 30) => { "usd" => BigDecimal("1.1138"), "jpy" => BigDecimal("132.97") },
    Date.new(2022, 1, 31) => { "usd" => BigDecimal("1.1156"), "jpy" => BigDecimal("131.2") },
    Date.new(2022, 2, 1) => { "usd" => BigDecimal("1.126"), "jpy" => BigDecimal("130.15") },
    Date.new(2022, 2, 2) => { "usd" => BigDecimal("1.1323"), "jpy" => BigDecimal("133.91") },
    Date.new(2022, 2, 15) => { "usd" => BigDecimal("1.1483"), "jpy" => BigDecimal("149.93") },
    Date.new(2022, 2, 16) => { "usd" => BigDecimal("1.1482"), "jpy" => BigDecimal("149.93") }
  )

  # code, origin, destination, departure, arrival, amount, currency (MNOP uses the highest rate)
  ROWS = [
    [ "ABCD", "CNSHA", "NLRTM", "2022-02-01", "2022-03-01", "589.30", "USD" ],
    [ "EFGH", "CNSHA", "NLRTM", "2022-02-02", "2022-03-02", "890.32", "EUR" ],
    [ "IJKL", "CNSHA", "NLRTM", "2022-01-31", "2022-02-28", "97453", "JPY" ],
    [ "MNOP", "CNSHA", "NLRTM", "2022-01-30", "2022-03-05", "812.00", "USD" ],
    [ "QRST", "CNSHA", "NLRTM", "2022-01-29", "2022-02-15", "761.96", "EUR" ],
    [ "ERXQ", "CNSHA", "ESBCN", "2022-01-29", "2022-02-12", "261.96", "EUR" ],
    [ "ETRF", "ESBCN", "NLRTM", "2022-02-15", "2022-03-29", "70.96", "USD" ],
    [ "ETRG", "ESBCN", "NLRTM", "2022-02-16", "2022-02-20", "69.96", "USD" ],
    [ "ETRB", "ESBCN", "BRSSZ", "2022-02-16", "2022-03-14", "439.96", "USD" ]
  ].freeze

  def sample_sailings
    ROWS.map do |code, from, to, departs, arrives, amount, currency|
      rate = Freight::Rate.parse(amount, currency)
      departure = Date.parse(departs)
      Freight::Sailing.new(
        code: code, origin_port: from, destination_port: to,
        departure_date: departure, arrival_date: Date.parse(arrives),
        rate: rate, price_eur: EXCHANGE_RATES.to_eur(rate, on: departure)
      )
    end
  end

  def sample_repository
    InMemorySailingRepository.new(sample_sailings)
  end
end

RSpec.configure { |config| config.include SampleSchedule }
