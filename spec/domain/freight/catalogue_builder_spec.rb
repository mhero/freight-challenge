require "rails_helper"

RSpec.describe Freight::CatalogueBuilder do
  let(:exchange_rates) { build_exchange_rates("2022-02-01" => { "USD" => "1.25" }) }
  let(:priced) { build_sailing(code: "AAAA") }
  let(:no_rate) { build_sailing(code: "BBBB") }
  let(:no_exchange_rate) { build_sailing(code: "CCCC", departure: "2022-02-05", arrival: "2022-02-20") }
  let(:usd) { build_sailing(code: "DDDD", origin: "ESBCN", destination: "NLRTM") }
  let(:sailings) { [ priced, no_rate, no_exchange_rate, usd ] }
  let(:rates) do
    [
      build_rate("AAAA", "10.00", "EUR"),
      build_rate("CCCC", "5.00", "USD"),
      build_rate("DDDD", "100.00", "USD")
    ]
  end

  subject(:catalogue) { described_class.new(exchange_rates).build(sailings: sailings, rates: rates) }

  it "keeps only the sailings that can be priced" do
    expect(catalogue.priced_sailings.map(&:code)).to eq(%w[AAAA DDDD])
  end

  it "reports why the others were left out" do
    expect(catalogue.issues.map { |issue| [ issue.kind, issue.sailing_code ] }).to eq(
      [ [ :missing_rate, "BBBB" ], [ :missing_exchange_rate, "CCCC" ] ]
    )
  end

  it "keeps the original price and the EUR price on each priced sailing" do
    leg = catalogue.priced_sailings.last

    expect(leg.price).to eq(money("100.00", "USD"))
    expect(leg.eur_price.amount).to eq(BigDecimal("80"))
    expect(leg.origin).to eq(Freight::PortCode.new("ESBCN"))
  end

  it "includes the conflict issues of resolved sailings" do
    conflicting = rates + [ build_rate("AAAA", "20.00", "EUR") ]
    catalogue = described_class.new(exchange_rates).build(sailings: sailings, rates: conflicting)

    expect(catalogue.issues.map(&:kind)).to include(:conflicting_rate)
    expect(catalogue.priced_sailings.first.price).to eq(money("20.00", "EUR"))
  end

  it "ignores rates of sailings that are not in the feed (orphans are reported by the import)" do
    catalogue = described_class.new(exchange_rates).build(sailings: [ priced ], rates: rates)

    expect(catalogue.priced_sailings.map(&:code)).to eq([ "AAAA" ])
  end

  describe "Catalogue#sailings_between" do
    it "returns the priced sailings of a port pair, accepting raw port strings" do
      expect(catalogue.sailings_between("cnsha", "nlrtm").map(&:code)).to eq([ "AAAA" ])
      expect(catalogue.sailings_between(Freight::PortCode.new("ESBCN"), "NLRTM").map(&:code)).to eq([ "DDDD" ])
    end

    it "returns an empty list for unknown pairs and is directional" do
      expect(catalogue.sailings_between("NLRTM", "CNSHA")).to eq([])
      expect(catalogue.sailings_between("BRSSZ", "CNSHA")).to eq([])
    end
  end

  it "builds an immutable catalogue" do
    expect(catalogue.priced_sailings).to be_frozen
    expect(catalogue.issues).to be_frozen
  end
end
