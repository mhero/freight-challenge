require "rails_helper"

RSpec.describe Sailing do
  describe ".reachable_priced" do
    let!(:early) { create(:sailing, sailing_code: "BBBB", departure_date: Date.new(2022, 2, 1), arrival_date: Date.new(2022, 2, 5)) }
    let!(:late) { create(:sailing, sailing_code: "AAAA", departure_date: Date.new(2022, 2, 10)) }

    before do
      create(:exchange_rate, date: Date.new(2022, 2, 1), currency: "usd")
      create(:rate, sailing: early, amount: "10.00", currency: "USD")
      create(:rate, sailing: late, amount: "20.00", currency: "EUR")
    end

    def codes(origin = "CNSHA")
      described_class.reachable_priced(origin).rows.map(&:first)
    end

    it "returns the rate of the import that last saw the sailing, ordered by departure" do
      result = described_class.reachable_priced("CNSHA")

      expect(result.columns).to eq(%w[ sailing_code origin_port destination_port departure_date arrival_date rate_amount rate_currency ])
      expect(result.rows.map(&:first)).to eq(%w[ BBBB AAAA ])
      expect(result.rows.first.last(2)).to eq(%w[ 10.00 USD ])
    end

    it "keeps only sailings leaving the given origin or reachable from it" do
      create(:sailing, origin_port: "ESBCN", destination_port: "BRSSZ", departure_date: Date.new(2022, 2, 5)).tap { |other| create(:rate, sailing: other) }

      expect(codes("CNSHA").size).to eq(3)
      expect(codes("ESBCN").size).to eq(1)
    end

    it "skips inactive sailings" do
      late.update!(active: false)

      expect(codes).to eq(%w[ BBBB ])
    end

    it "skips sailings without a rate in their last seen import" do
      early.update!(last_seen_import: create(:feed_import))

      expect(codes).to eq(%w[ AAAA ])
    end

    it "skips non-EUR sailings without an exchange rate for their departure date" do
      ExchangeRate.delete_all

      expect(codes).to eq(%w[ AAAA ])
    end
  end

  describe ".known_ports" do
    before { create(:sailing, origin_port: "CNSHA", destination_port: "NLRTM") }

    it "returns the given ports that appear in an active sailing, in one query" do
      expect(described_class.known_ports(%w[ CNSHA NLRTM ZZZZZ ])).to contain_exactly("CNSHA", "NLRTM")
    end

    it "ignores ports of inactive sailings and an empty list" do
      create(:sailing, origin_port: "BRSSZ", destination_port: "DEHAM", active: false)

      expect(described_class.known_ports(%w[ BRSSZ ])).to eq([])
      expect(described_class.known_ports([])).to eq([])
    end
  end
end
