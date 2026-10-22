require "rails_helper"

RSpec.describe Freight::RateResolver do
  subject(:resolver) { described_class.new(exchange_rates) }

  let(:exchange_rates) { build_exchange_rates("2022-02-01" => { "USD" => "1.25" }) }
  let(:sailing) { build_sailing(departure: "2022-02-01", arrival: "2022-03-01") }

  def resolve(*prices)
    resolver.resolve(sailing, prices)
  end

  it "prices a sailing with a single rate and converts it with the departure-date rate" do
    resolution = resolve(money("100.00", "USD"))

    expect(resolution).to be_priced
    expect(resolution.price).to eq(money("100.00", "USD"))
    expect(resolution.eur_price.amount).to eq(BigDecimal("80"))
    expect(resolution.issues).to be_empty
  end

  it "needs no exchange rate for EUR" do
    resolution = described_class.new(build_exchange_rates).resolve(sailing, [ money("261.96", "EUR") ])

    expect(resolution.price).to eq(money("261.96", "EUR"))
    expect(resolution.eur_price).to eq(money("261.96", "EUR"))
  end

  describe "conflicting rates (the MNOP case, P1)" do
    it "keeps the highest rate and reports the discarded one" do
      resolution = resolve(money("456.78", "USD"), money("812.00", "USD"))

      expect(resolution.price).to eq(money("812.00", "USD"))
      expect(resolution.issues).to contain_exactly(
        Freight::DataIssue.new(
          kind: :conflicting_rate,
          sailing_code: "ABCD",
          details: { kept: "812.00 USD", discarded: "456.78 USD" }
        )
      )
    end

    it "does not depend on the order of the rates" do
      forward = resolve(money("456.78", "USD"), money("812.00", "USD"))
      backward = resolve(money("812.00", "USD"), money("456.78", "USD"))

      expect(backward.price).to eq(forward.price)
      expect(backward.issues).to eq(forward.issues)
    end

    it "reports every discarded rate when there are more than two" do
      resolution = resolve(money("10.00", "USD"), money("30.00", "USD"), money("20.00", "USD"))

      expect(resolution.price).to eq(money("30.00", "USD"))
      expect(resolution.issues.map { |issue| issue.details[:discarded] }).to contain_exactly("10.00 USD", "20.00 USD")
    end

    it "compares across currencies in EUR, not by nominal amount" do
      # 600 USD = 480 EUR, lower than 500 EUR even though 600 > 500
      expect(resolve(money("500.00", "EUR"), money("600.00", "USD")).price).to eq(money("500.00", "EUR"))
      # 700 USD = 560 EUR
      expect(resolve(money("500.00", "EUR"), money("700.00", "USD")).price).to eq(money("700.00", "USD"))
    end

    it "breaks an EUR tie with the alphabetically lowest currency code" do
      resolution = resolve(money("125.00", "USD"), money("100.00", "EUR"))

      expect(resolution.price).to eq(money("100.00", "EUR"))
      expect(resolution.issues.first.details[:discarded]).to eq("125.00 USD")
    end

    it "collapses identical duplicates without reporting a conflict" do
      resolution = resolve(money("589.30", "USD"), money("589.3", "USD"))

      expect(resolution.price).to eq(money("589.30", "USD"))
      expect(resolution.issues).to be_empty
    end
  end

  describe "missing data (P4)" do
    it "leaves a sailing without any rate unpriced and reports it" do
      resolution = resolve

      expect(resolution).not_to be_priced
      expect(resolution.issues).to contain_exactly(
        Freight::DataIssue.new(kind: :missing_rate, sailing_code: "ABCD")
      )
    end

    it "leaves a sailing unpriced when the exchange rate is missing for its departure date" do
      resolution = resolve(money("97453", "JPY"))

      expect(resolution).not_to be_priced
      expect(resolution.price).to be_nil
      expect(resolution.issues).to contain_exactly(
        Freight::DataIssue.new(
          kind: :missing_exchange_rate,
          sailing_code: "ABCD",
          details: { currency: "JPY", date: "2022-02-01" }
        )
      )
    end

    it "does not fall back to another date" do
      resolver = described_class.new(build_exchange_rates("2022-01-31" => { "USD" => "1.25" }))

      expect(resolver.resolve(sailing, [ money("100.00", "USD") ])).not_to be_priced
    end

    it "cannot resolve a conflict it cannot compare, so the sailing stays unpriced" do
      resolution = resolve(money("100.00", "EUR"), money("100", "JPY"))

      expect(resolution).not_to be_priced
      expect(resolution.issues.map(&:kind)).to eq([ :missing_exchange_rate ])
    end
  end
end
