require "rails_helper"

RSpec.describe Freight::RateResolver do
  subject(:resolver) { described_class.new(exchange_rates) }

  let(:date) { Date.new(2022, 1, 30) }
  let(:exchange_rates) { Freight::ExchangeRates.new(date => { "usd" => BigDecimal("1.1138") }) }

  def rate(text, currency)
    Freight::Rate.parse(text, currency)
  end

  def resolve(*candidates)
    resolver.resolve(departure_date: date, candidates: candidates)
  end

  it "prices a sailing with a single rate" do
    result = resolve(rate("456.78", "USD"))

    expect(result).to be_priced
    expect(result.rate).to eq(rate("456.78", "USD"))
    expect(result.conflict).to be(false)
    expect(result.price_eur).to be_within(BigDecimal("0.001")).of(BigDecimal("410.098"))
  end

  it "keeps the highest rate when candidates conflict (MNOP)" do
    low = rate("456.78", "USD")
    high = rate("812.00", "USD")

    [ [ low, high ], [ high, low ] ].each do |order|
      result = resolve(*order)

      expect(result.rate).to eq(high)
      expect(result.discarded).to eq([ low ])
      expect(result.conflict).to be(true)
    end
  end

  it "compares conflicting candidates in EUR" do
    result = resolve(rate("100.00", "EUR"), rate("130.00", "USD"))

    expect(result.rate).to eq(rate("130.00", "USD"))
  end

  it "collapses identical duplicates without reporting a conflict" do
    result = resolve(rate("10.00", "USD"), rate("10.00", "USD"), rate("10.0", "USD"))

    expect(result.conflict).to be(false)
    expect(result.discarded).to be_empty
    expect(result).to be_priced
  end

  it "leaves the sailing unpriced when a conflicting candidate cannot be converted" do
    result = resolve(rate("456.78", "USD"), rate("500", "CHF"))

    expect(result).not_to be_priced
    expect(result.conflict).to be(true)
    expect(result.unpriced_reason).to include("CHF")
  end

  it "leaves the sailing unpriced when there is no exchange rate for the date" do
    result = resolver.resolve(departure_date: Date.new(2022, 3, 1), candidates: [ rate("1.00", "USD") ])

    expect(result).not_to be_priced
    expect(result.unpriced_reason).to eq("no exchange rate for USD on 2022-03-01")
  end

  it "leaves the sailing unpriced when the feed has no rate for it" do
    result = resolve

    expect(result).not_to be_priced
    expect(result.unpriced_reason).to eq("no rate in feed")
  end
end
