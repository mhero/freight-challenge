require "rails_helper"

RSpec.describe Freight::Rate do
  describe ".parse" do
    it "keeps the amount text exactly as received and normalizes the currency" do
      rate = described_class.parse("232.30", " usd ")

      expect(rate.amount_text).to eq("232.30")
      expect(rate.currency).to eq("USD")
      expect(rate.amount).to eq(BigDecimal("232.30"))
    end

    it "accepts JPY amounts without decimals and with zero decimals" do
      expect(described_class.parse("97453", "JPY").amount_text).to eq("97453")
      expect(described_class.parse("97453.00", "JPY").amount_text).to eq("97453.00")
    end

    it "checks precision by value, not by the number of digits written" do
      expect(described_class.parse("589.300", "USD").amount_text).to eq("589.300")
    end

    it "rejects an amount that rounding would change" do
      expect { described_class.parse("12.345", "USD") }.to raise_error(Freight::InvalidRate, /decimal places/)
      expect { described_class.parse("100.5", "JPY") }.to raise_error(Freight::InvalidRate, /decimal places/)
    end

    it "rejects malformed amounts" do
      [ "abc", "-1", "1e3", "", " 5", nil, 12.5 ].each do |amount|
        expect { described_class.parse(amount, "USD") }.to raise_error(Freight::InvalidRate, /invalid amount/)
      end
    end

    it "rejects malformed currencies" do
      [ "US", "", nil, "U5D" ].each do |currency|
        expect { described_class.parse("1.00", currency) }.to raise_error(Freight::InvalidRate, /invalid currency/)
      end
    end
  end

  it "is equal to another rate with the same text and currency" do
    expect(described_class.parse("1.00", "USD")).to eq(described_class.parse("1.00", "usd"))
  end
end
