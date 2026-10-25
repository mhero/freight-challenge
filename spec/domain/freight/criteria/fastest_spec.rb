require "rails_helper"

RSpec.describe Freight::Criteria::Fastest do
  subject(:criterion) { described_class.new }

  def leg(code, from, to, departs, arrives, eur)
    build_sailing(code: code, from: from, to: to, departs: departs, arrives: arrives, eur: eur)
  end

  it "is named after the ticket criterion and has no leg limit" do
    expect(criterion.name).to eq("fastest")
    expect(criterion.max_legs).to be_nil
  end

  describe "on the sample schedule" do
    it "returns QRST: 17 days, against 22 days for ERXQ + ETRG" do
      route = sample_search.best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

      expect(route.sailing_codes).to eq(%w[ QRST ])
      expect(route.duration_days).to eq(17)
    end
  end

  it "counts layovers in the journey time" do
    with_layover = build_route(
      leg("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-03", "10"),
      leg("BBBB", "ESBCN", "NLRTM", "2022-01-20", "2022-01-22", "10")
    )
    slow_direct = build_route(leg("CCCC", "CNSHA", "NLRTM", "2022-01-01", "2022-01-15", "500"))

    expect(with_layover.duration_days).to eq(21)
    expect(criterion.best([ with_layover, slow_direct ])).to eq(slow_direct)
  end

  describe "tie-breaks" do
    let(:cheap_two_legs) do
      build_route(
        leg("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-05", "10"),
        leg("BBBB", "ESBCN", "NLRTM", "2022-01-05", "2022-01-10", "10")
      )
    end

    it "prefers the lower total price at equal duration" do
      pricey = build_route(leg("ZZZZ", "CNSHA", "NLRTM", "2022-01-01", "2022-01-10", "500"))

      expect(criterion.best([ pricey, cheap_two_legs ])).to eq(cheap_two_legs)
    end

    it "then prefers fewer legs" do
      one_leg = build_route(leg("ZZZZ", "CNSHA", "NLRTM", "2022-01-01", "2022-01-10", "20"))

      expect(criterion.best([ cheap_two_legs, one_leg ])).to eq(one_leg)
    end

    it "then prefers the lower sailing codes" do
      first = build_route(leg("AAAA", "CNSHA", "NLRTM", "2022-01-01", "2022-01-10", "20"))
      second = build_route(leg("BBBB", "CNSHA", "NLRTM", "2022-01-01", "2022-01-10", "20"))

      expect(criterion.best([ second, first ])).to eq(first)
    end
  end
end
