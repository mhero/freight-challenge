require "rails_helper"

# Policy checks against the bundled sample feed (docs/data_policy.md, section 3).
# The README's literal outputs are deliberately NOT asserted: they disagree with the JSON.
RSpec.describe "Sample feed" do
  let(:catalogue) { SampleFeed.catalogue }
  let(:cheapest_direct) { Freight::Criteria.find("cheapest-direct") }

  it "prices every sailing of the sample" do
    expect(catalogue.priced_sailings.size).to eq(9)
  end

  it "keeps the highest MNOP rate and reports the discarded one (P1)" do
    mnop = catalogue.priced_sailings.find { |leg| leg.code == "MNOP" }

    expect(mnop.price).to eq(money("812.00", "USD"))
    expect(mnop.eur_price.amount.round(4)).to eq(BigDecimal("729.0357"))
    expect(catalogue.issues).to contain_exactly(
      Freight::DataIssue.new(
        kind: :conflicting_rate,
        sailing_code: "MNOP",
        details: { kept: "812.00 USD", discarded: "456.78 USD" }
      )
    )
  end

  it "converts with the departure-date rate, dividing by the EUR-based rate" do
    eur_by_code = catalogue.priced_sailings.to_h { |leg| [ leg.code, leg.eur_price.amount.round(4) ] }

    expect(eur_by_code).to include(
      "ABCD" => BigDecimal("523.357"), # 589.30 USD / 1.126 (2022-02-01)
      "IJKL" => BigDecimal("742.782"), # 97453 JPY / 131.2 (2022-01-31)
      "EFGH" => BigDecimal("890.32"), # EUR, unchanged
      "ETRG" => BigDecimal("60.9302") # 69.96 USD / 1.1482 (2022-02-16)
    )
  end

  it "answers cheapest-direct CNSHA to NLRTM with ABCD" do
    route = cheapest_direct.best_route(catalogue, origin: "CNSHA", destination: "NLRTM")

    expect(route.sailing_codes).to eq([ "ABCD" ])
    expect(route.total_eur.amount.round(4)).to eq(BigDecimal("523.357"))
  end

  it "prints the cheapest-direct answer in the README format" do
    route = cheapest_direct.best_route(catalogue, origin: "CNSHA", destination: "NLRTM")

    expect(Freight::RouteSerializer.call(route)).to eq(
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

  it "has no direct sailing from CNSHA to BRSSZ" do
    expect(cheapest_direct.best_route(catalogue, origin: "CNSHA", destination: "BRSSZ")).to be_nil
  end
end
