require "rails_helper"

RSpec.describe Freight::Money do
  describe ".parse" do
    it "parses a decimal string into a BigDecimal amount" do
      parsed = described_class.parse("589.30", "usd")

      expect(parsed.amount).to eq(BigDecimal("589.30"))
      expect(parsed.amount).to be_a(BigDecimal)
      expect(parsed.currency).to eq(Freight::Currency.new("USD"))
    end

    it "accepts whole amounts and JPY without decimals" do
      expect(described_class.parse("97453", "JPY").amount).to eq(BigDecimal("97453"))
      expect(described_class.parse("812", "USD").amount).to eq(BigDecimal("812"))
    end

    it "accepts trailing zeros that do not lose information" do
      expect(described_class.parse("97453.00", "JPY").amount).to eq(BigDecimal("97453"))
    end

    it "rejects more decimals than the currency allows instead of rounding" do
      expect { described_class.parse("10.123", "USD") }.to raise_error(Freight::Errors::InvalidMoney, /decimals/)
      expect { described_class.parse("97453.5", "JPY") }.to raise_error(Freight::Errors::InvalidMoney, /decimals/)
    end

    [ "", "abc", "-5", "1e3", "1,5", ".5", "0", "0.00", "12.", nil, 12.5, 12 ].each do |bad|
      it "rejects #{bad.inspect}" do
        expect { described_class.parse(bad, "USD") }.to raise_error(Freight::Errors::InvalidMoney)
      end
    end

    it "rejects a malformed currency" do
      expect { described_class.parse("10.00", "DOLLARS") }.to raise_error(Freight::Errors::InvalidCurrency)
    end
  end

  describe ".new" do
    it "only accepts BigDecimal amounts (no floats for money)" do
      expect { described_class.new(amount: 1.5, currency: Freight::Currency::EUR) }
        .to raise_error(Freight::Errors::InvalidMoney)
    end

    it "only accepts a Currency" do
      expect { described_class.new(amount: BigDecimal("1"), currency: "EUR") }
        .to raise_error(Freight::Errors::InvalidMoney)
    end
  end

  describe "#formatted_amount" do
    it "uses the minor units of the currency" do
      expect(money("589.3", "USD").formatted_amount).to eq("589.30")
      expect(money("70.9", "EUR").formatted_amount).to eq("70.90")
      expect(money("812", "USD").formatted_amount).to eq("812.00")
      expect(money("97453", "JPY").formatted_amount).to eq("97453")
      expect(money("97453.00", "JPY").formatted_amount).to eq("97453")
    end

    it "is part of #to_s" do
      expect(money("456.78", "USD").to_s).to eq("456.78 USD")
    end
  end

  describe "#+" do
    it "adds amounts of the same currency without losing precision" do
      total = money("261.96", "EUR") + money("69.96", "EUR")

      expect(total.amount).to eq(BigDecimal("331.92"))
      expect(total.currency).to eq(Freight::Currency::EUR)
    end

    it "refuses to add different currencies" do
      expect { money("1.00", "EUR") + money("1.00", "USD") }.to raise_error(Freight::Errors::CurrencyMismatch)
    end

    it "refuses to add something that is not money" do
      expect { money("1.00", "EUR") + 1 }.to raise_error(Freight::Errors::CurrencyMismatch)
    end
  end

  it "is a value object" do
    expect(money("10.0", "EUR")).to eq(money("10.00", "EUR"))
    expect(money("10.00", "EUR")).not_to eq(money("10.00", "USD"))
  end
end
