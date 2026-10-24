require "rails_helper"

RSpec.describe Freight::ExchangeRates do
  subject(:rates) { described_class.new(table) }

  let(:table) do
    {
      Date.new(2022, 2, 1) => { "usd" => BigDecimal("1.126") },
      Date.new(2022, 1, 31) => { "jpy" => BigDecimal("131.2") }
    }
  end

  def rate(text, currency)
    Freight::Rate.parse(text, currency)
  end

  it "treats EUR as 1 on any date" do
    expect(rates.to_eur(rate("261.96", "EUR"), on: Date.new(2030, 1, 1))).to eq(BigDecimal("261.96"))
  end

  it "divides by the EUR-based rate of the given date" do
    eur = rates.to_eur(rate("589.30", "USD"), on: Date.new(2022, 2, 1))

    expect(eur).to be_within(BigDecimal("0.001")).of(BigDecimal("523.357"))
  end

  it "converts currencies without decimals" do
    eur = rates.to_eur(rate("97453", "JPY"), on: Date.new(2022, 1, 31))

    expect(eur).to be_within(BigDecimal("0.001")).of(BigDecimal("742.78"))
  end

  it "returns nil when the date has no rate for the currency, without carrying forward" do
    expect(rates.to_eur(rate("1.00", "USD"), on: Date.new(2022, 2, 2))).to be_nil
    expect(rates.to_eur(rate("1.00", "USD"), on: Date.new(2022, 1, 31))).to be_nil
  end

  it "returns nil for a zero or negative exchange rate" do
    broken = described_class.new(Date.new(2022, 2, 1) => { "usd" => BigDecimal("0") })

    expect(broken.to_eur(rate("1.00", "USD"), on: Date.new(2022, 2, 1))).to be_nil
  end
end
