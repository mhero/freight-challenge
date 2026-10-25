require "rails_helper"

RSpec.describe Freight::Criteria::Cheapest do
  subject(:criterion) { described_class.new }

  def leg(code, from, to, departs, arrives, eur)
    build_sailing(code: code, from: from, to: to, departs: departs, arrives: arrives, eur: eur)
  end

  it "is named after the ticket criterion and has no leg limit" do
    expect(criterion.name).to eq("cheapest")
    expect(criterion.max_legs).to be_nil
  end

  describe "on the sample schedule" do
    let(:search) { Freight::RouteSearch.new(repository: sample_repository) }

    it "returns all legs of the cheapest option: ERXQ + ETRG" do
      route = search.best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

      expect(route.sailing_codes).to eq(%w[ ERXQ ETRG ])
      expect(route.total_eur).to be_within(BigDecimal("0.01")).of(BigDecimal("322.89"))
    end

    it "prefers the two-leg route over a direct sailing when the sum is lower" do
      direct = search.best_route(origin: "CNSHA", destination: "NLRTM", criterion: Freight::Criteria::CheapestDirect.new)
      indirect = search.best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

      expect(indirect.total_eur).to be < direct.total_eur
    end
  end

  describe "tie-breaks" do
    it "prefers fewer legs at equal total" do
      two_legs = build_route(
        leg("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-02", "50"),
        leg("BBBB", "ESBCN", "NLRTM", "2022-01-03", "2022-01-04", "50")
      )
      one_leg = build_route(leg("ZZZZ", "CNSHA", "NLRTM", "2022-01-01", "2022-02-01", "100"))

      expect(criterion.best([ two_legs, one_leg ])).to eq(one_leg)
    end

    it "then prefers the earlier arrival" do
      late = build_route(leg("AAAA", "CNSHA", "NLRTM", "2022-01-01", "2022-02-10", "100"))
      early = build_route(leg("ZZZZ", "CNSHA", "NLRTM", "2022-01-02", "2022-02-01", "100"))

      expect(criterion.best([ late, early ])).to eq(early)
    end

    it "then prefers the lower sailing codes" do
      first = build_route(
        leg("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-02", "50"),
        leg("BBBB", "ESBCN", "NLRTM", "2022-01-03", "2022-01-10", "50")
      )
      second = build_route(
        leg("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-02", "50"),
        leg("CCCC", "ESBCN", "NLRTM", "2022-01-03", "2022-01-10", "50")
      )

      expect(criterion.best([ second, first ])).to eq(first)
    end

    it "lets the tie-break decide between equal-cost alternatives" do
      repository = InMemorySailingRepository.new(
        [
          leg("BBBB", "CNSHA", "NLRTM", "2022-02-01", "2022-03-10", "100"),
          leg("AAAA", "CNSHA", "NLRTM", "2022-02-02", "2022-03-01", "100")
        ]
      )

      route = Freight::RouteSearch.new(repository: repository)
                                  .best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

      expect(route.sailing_codes).to eq(%w[ AAAA ])
    end
  end
end
