require "rails_helper"

RSpec.describe Freight::CurrencyPrecision do
  it "knows the configured currencies" do
    expect(described_class.places_for("JPY")).to eq(0)
    expect(described_class.places_for("usd")).to eq(2)
    expect(described_class.places_for("EUR")).to eq(2)
  end

  it "falls back to two places for other currencies" do
    expect(described_class.places_for("CHF")).to eq(2)
  end
end
