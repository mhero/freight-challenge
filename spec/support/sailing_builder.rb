# Builds priced domain sailings for unit specs (no database involved).
module SailingBuilder
  def build_sailing(code:, from:, to:, departs:, arrives:, eur:, rate: nil)
    rate ||= Freight::Rate.parse(format("%.2f", eur), "EUR")
    Freight::Sailing.new(
      code: code, origin_port: from, destination_port: to,
      departure_date: Date.parse(departs), arrival_date: Date.parse(arrives),
      rate: rate, price_eur: BigDecimal(eur.to_s)
    )
  end

  def build_route(*sailings)
    Freight::Route.new(sailings)
  end
end

RSpec.configure { |config| config.include SailingBuilder }
