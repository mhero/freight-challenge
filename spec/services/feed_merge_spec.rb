require "rails_helper"

RSpec.describe FeedMerge do
  subject(:merge) { described_class.new(exchange_rates) }

  let(:day) { Date.new(2022, 1, 30) }
  let(:exchange_rates) { Freight::ExchangeRates.new(day => { "usd" => BigDecimal("1.1138") }) }

  def sailing(code, departs: day)
    Freight::SailingRecord.new(
      code: code, origin_port: "CNSHA", destination_port: "NLRTM",
      departure_date: departs, arrival_date: departs + 30
    )
  end

  def rate(code, amount, currency)
    MapReduceFeed::RateRecord.new(sailing_code: code, rate: Freight::Rate.parse(amount, currency))
  end

  def run(sailings, rates)
    merge.call(sailing_records: sailings, rate_records: rates)
  end

  it "resolves MNOP to its highest rate and records the discarded one" do
    result = run([ sailing("MNOP") ], [ rate("MNOP", "456.78", "USD"), rate("MNOP", "812.00", "USD") ])

    expect(result.resolutions["MNOP"].rate.amount_text).to eq("812.00")
    issue = result.issues.sole
    expect(issue.kind).to eq("rate_conflict")
    expect(issue.details).to eq("kept" => { "amount" => "812.00", "currency" => "USD" },
                                "discarded" => [ { "amount" => "456.78", "currency" => "USD" } ])
  end

  it "leaves a sailing unpriced when a conflicting candidate cannot be converted" do
    result = run([ sailing("ABCD") ], [ rate("ABCD", "10.00", "USD"), rate("ABCD", "10.00", "CHF") ])

    expect(result.resolutions["ABCD"]).not_to be_priced
    expect(result.issues.sole.kind).to eq("rate_conflict")
    expect(result.issues.sole.reason).to include("no exchange rate for CHF")
  end

  it "reports a sailing without a usable rate as unpriced" do
    result = run(
      [ sailing("NORT"), sailing("NOFX", departs: day + 1) ],
      [ rate("NOFX", "10.00", "USD") ]
    )

    expect(result.issues.map(&:kind)).to eq(%w[ unpriced unpriced ])
    expect(result.issues.map(&:reason)).to eq([ "no rate in feed", "no exchange rate for USD on 2022-01-31" ])
  end

  it "excludes conflicting sailings and reports rates without a sailing" do
    other = Freight::SailingRecord.new(
      code: "ABCD", origin_port: "CNSHA", destination_port: "NLRTM", departure_date: day, arrival_date: day + 31
    )

    result = run([ sailing("ABCD"), other ], [ rate("ABCD", "1.00", "EUR"), rate("GHOST", "1.00", "EUR") ])

    expect(result.sailings).to be_empty
    expect(result.issues.map(&:kind)).to eq(%w[ sailing_conflict orphan_rate ])
    expect(result.issues.last.reference).to eq("GHOST")
  end

  it "reports nothing for clean data and collapses identical duplicates" do
    result = run([ sailing("ABCD"), sailing("ABCD") ], [ rate("ABCD", "5.00", "EUR"), rate("ABCD", "5.00", "EUR") ])

    expect(result.issues).to be_empty
    expect(result.sailings.size).to eq(1)
    expect(result.resolutions["ABCD"]).to be_priced
  end
end
