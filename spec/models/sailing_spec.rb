require "rails_helper"

RSpec.describe Sailing do
  describe ".priced_departures" do
    let!(:early) { create(:sailing, sailing_code: "BBBB", departure_date: Date.new(2022, 2, 1)) }
    let!(:late) { create(:sailing, sailing_code: "AAAA", departure_date: Date.new(2022, 2, 10)) }

    before do
      create(:rate, sailing: early, amount: "10.00", currency: "USD")
      create(:rate, sailing: late, amount: "20.00", currency: "EUR")
    end

    it "returns the rate of the import that last saw the sailing, ordered by departure" do
      rows = described_class.priced_departures("CNSHA").to_a

      expect(rows.map(&:sailing_code)).to eq(%w[ BBBB AAAA ])
      expect(rows.first[:rate_amount]).to eq("10.00")
      expect(rows.first[:rate_currency]).to eq("USD")
    end

    it "filters by origin port" do
      create(:sailing, origin_port: "ESBCN").tap { |other| create(:rate, sailing: other) }

      expect(described_class.priced_departures("ESBCN").count).to eq(1)
    end

    it "keeps only departures on or after the given date" do
      rows = described_class.priced_departures("CNSHA", on_or_after: Date.new(2022, 2, 10)).to_a

      expect(rows.map(&:sailing_code)).to eq(%w[ AAAA ])
    end

    it "skips inactive sailings" do
      late.update!(active: false)

      expect(described_class.priced_departures("CNSHA").map(&:sailing_code)).to eq(%w[ BBBB ])
    end

    it "skips sailings without a rate in their last seen import" do
      newer_import = create(:feed_import)
      early.update!(last_seen_import: newer_import)

      expect(described_class.priced_departures("CNSHA").map(&:sailing_code)).to eq(%w[ AAAA ])
    end
  end
end
