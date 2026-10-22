require "rails_helper"

RSpec.describe Freight::Criteria::CheapestDirect do
  subject(:criterion) { described_class.new }

  def best_code(catalogue, origin: "CNSHA", destination: "NLRTM")
    criterion.best_route(catalogue, origin: origin, destination: destination)&.sailing_codes
  end

  it "is named cheapest-direct" do
    expect(criterion.name).to eq("cheapest-direct")
  end

  it "returns the cheapest direct sailing as a single-leg route" do
    catalogue = build_catalogue(
      [ build_sailing(code: "AAAA"), build_sailing(code: "BBBB"), build_sailing(code: "CCCC") ],
      [ build_rate("AAAA", "300.00", "EUR"), build_rate("BBBB", "100.00", "EUR"), build_rate("CCCC", "200.00", "EUR") ]
    )

    route = criterion.best_route(catalogue, origin: "CNSHA", destination: "NLRTM")

    expect(route).to be_direct
    expect(route.sailing_codes).to eq([ "BBBB" ])
  end

  it "ignores sailings of other port pairs and the reverse direction" do
    catalogue = build_catalogue(
      [
        build_sailing(code: "AAAA"),
        build_sailing(code: "BBBB", origin: "CNSHA", destination: "ESBCN"),
        build_sailing(code: "CCCC", origin: "NLRTM", destination: "CNSHA")
      ],
      [ build_rate("AAAA", "300.00", "EUR"), build_rate("BBBB", "1.00", "EUR"), build_rate("CCCC", "1.00", "EUR") ]
    )

    expect(best_code(catalogue)).to eq([ "AAAA" ])
  end

  it "does not use indirect routes" do
    catalogue = build_catalogue(
      [
        build_sailing(code: "AAAA", destination: "ESBCN", departure: "2022-01-29", arrival: "2022-02-12"),
        build_sailing(code: "BBBB", origin: "ESBCN", departure: "2022-02-16", arrival: "2022-02-20")
      ],
      [ build_rate("AAAA", "1.00", "EUR"), build_rate("BBBB", "1.00", "EUR") ]
    )

    expect(best_code(catalogue)).to be_nil
  end

  it "compares prices in EUR, not by nominal amount" do
    catalogue = build_catalogue(
      [ build_sailing(code: "AAAA"), build_sailing(code: "BBBB") ],
      [ build_rate("AAAA", "500.00", "EUR"), build_rate("BBBB", "600.00", "USD") ],
      build_exchange_rates("2022-02-01" => { "USD" => "1.25" })
    )

    expect(best_code(catalogue)).to eq([ "BBBB" ])
  end

  describe "tie-breaking" do
    it "prefers the earlier arrival when the EUR price is equal" do
      catalogue = build_catalogue(
        [ build_sailing(code: "AAAA", arrival: "2022-03-10"), build_sailing(code: "BBBB", arrival: "2022-03-01") ],
        [ build_rate("AAAA", "100.00", "EUR"), build_rate("BBBB", "100.00", "EUR") ]
      )

      expect(best_code(catalogue)).to eq([ "BBBB" ])
    end

    it "prefers the lower sailing code when price and arrival are equal, whatever the feed order" do
      sailings = [ build_sailing(code: "ZZZZ"), build_sailing(code: "AAAA") ]
      rates = [ build_rate("ZZZZ", "100.00", "EUR"), build_rate("AAAA", "100.00", "EUR") ]

      expect(best_code(build_catalogue(sailings, rates))).to eq([ "AAAA" ])
      expect(best_code(build_catalogue(sailings.reverse, rates.reverse))).to eq([ "AAAA" ])
    end
  end

  it "never returns a sailing that could not be priced" do
    catalogue = build_catalogue(
      [ build_sailing(code: "AAAA"), build_sailing(code: "BBBB"), build_sailing(code: "CCCC") ],
      [ build_rate("AAAA", "300.00", "EUR"), build_rate("CCCC", "1.00", "JPY") ]
    )

    expect(best_code(catalogue)).to eq([ "AAAA" ])
  end

  it "returns nil when no sailing exists for the pair" do
    expect(best_code(build_catalogue([], []))).to be_nil
  end

  it "accepts raw port strings" do
    catalogue = build_catalogue([ build_sailing(code: "AAAA") ], [ build_rate("AAAA", "1.00", "EUR") ])

    expect(best_code(catalogue, origin: " cnsha", destination: "nlrtm")).to eq([ "AAAA" ])
  end
end
