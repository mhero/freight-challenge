require "rails_helper"

RSpec.describe Freight::Currency do
  it "normalizes to upper case" do
    expect(described_class.new(" usd ").code).to eq("USD")
  end

  it "has two minor-unit digits by default and none for JPY" do
    expect(described_class.new("USD").exponent).to eq(2)
    expect(described_class.new("EUR").exponent).to eq(2)
    expect(described_class.new("JPY").exponent).to eq(0)
  end

  it "knows EUR" do
    expect(described_class::EUR).to be_eur
    expect(described_class.new("usd")).not_to be_eur
    expect(described_class.new("eur")).to eq(described_class::EUR)
  end

  [ "", nil, "US", "USDX", "U5D" ].each do |bad|
    it "rejects #{bad.inspect}" do
      expect { described_class.new(bad) }.to raise_error(Freight::Errors::InvalidCurrency)
    end
  end
end
