require "rails_helper"

RSpec.describe Freight::Route do
  let(:first_leg) { build_sailing(code: "ERXQ", from: "CNSHA", to: "ESBCN", departs: "2022-01-29", arrives: "2022-02-12", eur: "261.96") }
  let(:second_leg) { build_sailing(code: "ETRG", from: "ESBCN", to: "NLRTM", departs: "2022-02-16", arrives: "2022-02-20", eur: "60.93") }

  subject(:route) { described_class.new([ first_leg, second_leg ]) }

  it "exposes the ends of the journey" do
    expect(route.origin_port).to eq("CNSHA")
    expect(route.destination_port).to eq("NLRTM")
    expect(route.departure_date).to eq(Date.new(2022, 1, 29))
    expect(route.arrival_date).to eq(Date.new(2022, 2, 20))
  end

  it "measures duration from first departure to last arrival, layovers included" do
    expect(route.duration_days).to eq(22)
  end

  it "sums the EUR price of all legs" do
    expect(route.total_eur).to eq(BigDecimal("322.89"))
  end

  it "lists legs and sailing codes" do
    expect(route.leg_count).to eq(2)
    expect(route.sailing_codes).to eq(%w[ ERXQ ETRG ])
  end

  it "builds a longer route without changing the original" do
    third = build_sailing(code: "ZZZZ", from: "NLRTM", to: "DEHAM", departs: "2022-02-21", arrives: "2022-02-22", eur: "10")

    longer = route.extend_with(third)

    expect(longer.leg_count).to eq(3)
    expect(route.leg_count).to eq(2)
  end
end
