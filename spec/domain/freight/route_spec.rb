require "rails_helper"

RSpec.describe Freight::Route do
  let(:first_leg) { build_sailing(code: "AAAA", origin: "CNSHA", destination: "ESBCN", departure: "2022-01-29", arrival: "2022-02-12") }
  let(:second_leg) { build_sailing(code: "BBBB", origin: "ESBCN", destination: "NLRTM", departure: "2022-02-16", arrival: "2022-02-20") }
  let(:catalogue) do
    build_catalogue([ first_leg, second_leg ], [ build_rate("AAAA", "261.96", "EUR"), build_rate("BBBB", "69.96", "EUR") ])
  end
  let(:legs) { catalogue.priced_sailings }

  subject(:route) { described_class.new(legs: legs) }

  it "describes the whole journey" do
    expect(route.origin).to eq(Freight::PortCode.new("CNSHA"))
    expect(route.destination).to eq(Freight::PortCode.new("NLRTM"))
    expect(route.sailing_codes).to eq(%w[AAAA BBBB])
    expect(route.leg_count).to eq(2)
    expect(route).not_to be_direct
  end

  it "measures duration from first departure to last arrival, layovers included" do
    expect(route.departure_date).to eq(Date.iso8601("2022-01-29"))
    expect(route.arrival_date).to eq(Date.iso8601("2022-02-20"))
    expect(route.duration_days).to eq(22)
  end

  it "sums the EUR prices of all legs" do
    expect(route.total_eur).to eq(money("331.92", "EUR"))
  end

  it "is direct with a single leg" do
    expect(described_class.new(legs: [ legs.first ])).to be_direct
  end

  it "needs at least one leg" do
    expect { described_class.new(legs: []) }.to raise_error(Freight::Errors::InvalidRoute)
    expect { described_class.new(legs: nil) }.to raise_error(Freight::Errors::InvalidRoute)
  end

  it "does not expose its list of legs to mutation" do
    expect(route.legs).to be_frozen
  end
end
