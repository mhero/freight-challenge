require "rails_helper"

RSpec.describe Freight::ExchangeRates do
  subject(:rates) { build_exchange_rates("2022-02-01" => { "USD" => "1.25", "JPY" => "4" }) }

  let(:date) { Date.iso8601("2022-02-01") }

  describe "#rate_for" do
    it "returns the EUR-based rate for the exact date" do
      expect(rates.rate_for(Freight::Currency.new("USD"), date)).to eq(BigDecimal("1.25"))
    end

    it "treats EUR as an implicit rate of 1, even with no table at all" do
      expect(build_exchange_rates.rate_for(Freight::Currency::EUR, date)).to eq(BigDecimal("1"))
    end

    it "raises for a missing currency" do
      expect { rates.rate_for(Freight::Currency.new("GBP"), date) }
        .to raise_error(Freight::Errors::MissingExchangeRate, /GBP on 2022-02-01/)
    end

    it "raises for a missing date and does not fall back to a nearby one" do
      expect { rates.rate_for(Freight::Currency.new("USD"), date + 1) }
        .to raise_error(Freight::Errors::MissingExchangeRate) { |error|
          expect(error.currency).to eq(Freight::Currency.new("USD"))
          expect(error.date).to eq(date + 1)
        }
    end
  end

  describe "#to_eur" do
    it "divides by the EUR-based rate" do
      converted = rates.to_eur(money("100.00", "USD"), on: date)

      expect(converted.amount).to eq(BigDecimal("80"))
      expect(converted.currency).to eq(Freight::Currency::EUR)
    end

    it "converts currencies without decimals" do
      expect(rates.to_eur(money("97453", "JPY"), on: date).amount).to eq(BigDecimal("24363.25"))
    end

    it "keeps full precision instead of rounding" do
      thirds = build_exchange_rates("2022-02-01" => { "USD" => "3" })

      expect(thirds.to_eur(money("10.00", "USD"), on: date).amount.round(10)).to eq(BigDecimal("3.3333333333"))
    end

    it "returns EUR amounts unchanged" do
      eur = money("10.00", "EUR")

      expect(rates.to_eur(eur, on: date)).to equal(eur)
    end

    it "raises when the rate is missing" do
      expect { rates.to_eur(money("10.00", "GBP"), on: date) }.to raise_error(Freight::Errors::MissingExchangeRate)
    end
  end

  describe "validation" do
    it "rejects non-positive or non-BigDecimal rates" do
      usd = Freight::Currency.new("USD")
      date = Date.iso8601("2022-02-01")

      [ BigDecimal("0"), BigDecimal("-1"), 1.25, "1.25" ].each do |bad|
        expect { described_class.new(date => { usd => bad }) }.to raise_error(Freight::Errors::InvalidExchangeRate)
      end
    end

    it "rejects keys of the wrong type" do
      expect { described_class.new("2022-02-01" => { Freight::Currency.new("USD") => BigDecimal("1.1") }) }
        .to raise_error(Freight::Errors::InvalidExchangeRate)
      expect { described_class.new(Date.iso8601("2022-02-01") => { "USD" => BigDecimal("1.1") }) }
        .to raise_error(Freight::Errors::InvalidExchangeRate)
    end
  end
end
