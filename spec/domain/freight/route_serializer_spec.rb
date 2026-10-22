require "rails_helper"

RSpec.describe Freight::RouteSerializer do
  let(:exchange_rates) { build_exchange_rates("2022-02-01" => { "USD" => "1.126" }, "2022-01-31" => { "JPY" => "131.2" }) }
  let(:usd_leg) { build_sailing(code: "ABCD", departure: "2022-02-01", arrival: "2022-03-01") }
  let(:jpy_leg) { build_sailing(code: "IJKL", origin: "NLRTM", destination: "ESBCN", departure: "2022-03-02", arrival: "2022-03-04") }

  it "prints legs in the README format with the original rate and currency" do
    catalogue = build_catalogue([ usd_leg ], [ build_rate("ABCD", "589.30", "USD") ], exchange_rates)
    route = Freight::Route.new(legs: catalogue.priced_sailings)

    expect(described_class.call(route)).to eq(
      [
        {
          "origin_port" => "CNSHA",
          "destination_port" => "NLRTM",
          "departure_date" => "2022-02-01",
          "arrival_date" => "2022-03-01",
          "sailing_code" => "ABCD",
          "rate" => "589.30",
          "rate_currency" => "USD"
        }
      ]
    )
  end

  it "keeps the order of the legs" do
    rates = [ build_rate("ABCD", "589.30", "USD"), build_rate("IJKL", "97453", "EUR") ]
    legs = build_catalogue([ usd_leg, jpy_leg ], rates, exchange_rates).priced_sailings

    output = described_class.call(Freight::Route.new(legs: legs))

    expect(output.map { |leg| leg["sailing_code"] }).to eq(%w[ABCD IJKL])
  end

  it "prints JPY amounts without decimals" do
    jpy = build_sailing(code: "IJKL", departure: "2022-01-31", arrival: "2022-02-28")
    catalogue = build_catalogue([ jpy ], [ build_rate("IJKL", "97453", "JPY") ], exchange_rates)

    leg = described_class.call(Freight::Route.new(legs: catalogue.priced_sailings)).first

    expect(leg["rate"]).to eq("97453")
    expect(leg["rate_currency"]).to eq("JPY")
  end
end
