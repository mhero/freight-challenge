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
end

RSpec.describe Freight::Criteria::CheapestDirect, "on the sample schedule" do
  it "returns ABCD, the cheapest direct sailing (MNOP uses its highest rate)" do
    route = Freight::RouteSearch.new(repository: sample_repository)
                                .best_route(origin: "CNSHA", destination: "NLRTM", criterion: described_class.new)

    expect(route.sailing_codes).to eq(%w[ ABCD ])
    expect(route.total_eur).to be_within(BigDecimal("0.01")).of(BigDecimal("523.36"))
  end
end
