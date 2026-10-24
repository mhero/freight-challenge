require "rails_helper"

RSpec.describe Freight::Criteria::CheapestDirect do
  subject(:criterion) { described_class.new }

  def direct(code, eur, arrives: "2022-03-01")
    build_route(build_sailing(code: code, from: "CNSHA", to: "NLRTM", departs: "2022-02-01", arrives: arrives, eur: eur))
  end

  it "is limited to a single leg and named after the ticket criterion" do
    expect(criterion.name).to eq("cheapest-direct")
    expect(criterion.max_legs).to eq(1)
  end

  it "picks the route with the lowest EUR total" do
    routes = [ direct("ABCD", "523.36"), direct("EFGH", "890.32"), direct("QRST", "761.96") ]

    expect(criterion.best(routes).sailing_codes).to eq(%w[ ABCD ])
  end

  it "breaks price ties by earlier arrival, then by sailing code" do
    later = direct("AAAA", "100", arrives: "2022-03-05")
    earlier_b = direct("BBBB", "100", arrives: "2022-03-01")
    earlier_a = direct("AAAB", "100", arrives: "2022-03-01")

    expect(criterion.best([ later, earlier_b, earlier_a ]).sailing_codes).to eq(%w[ AAAB ])
  end

  it "returns nil when there is no route" do
    expect(criterion.best([])).to be_nil
  end

  it "prunes partial routes that already cost more than the best" do
    expect(criterion.prunable?(direct("X", "200"), direct("Y", "100"))).to be(true)
    expect(criterion.prunable?(direct("X", "100"), direct("Y", "100"))).to be(false)
  end
end
