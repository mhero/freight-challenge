require "rails_helper"

RSpec.describe MapReduceFeed do
  def parse(text)
    described_class.parse(text)
  end

  describe "the sample feed" do
    subject(:parsed) { parse(sample_feed) }

    it "reads every record without rejections" do
      expect(parsed.sailings.size).to eq(9)
      expect(parsed.rates.size).to eq(10)
      expect(parsed.exchange_rates.size).to eq(14)
      expect(parsed.rejections).to be_empty
    end

    it "keeps rate amounts as received and parses numbers as decimals" do
      expect(parsed.rates.first.rate.amount_text).to eq("589.30")
      expect(parsed.rates.find { |record| record.sailing_code == "IJKL" }.rate.amount_text).to eq("97453")
      usd = parsed.exchange_rates.find { |record| record.date == Date.new(2022, 1, 29) && record.currency == "usd" }
      expect(usd.rate).to eq(BigDecimal("1.1138"))
    end

    it "builds domain sailing records" do
      record = parsed.sailings.find { |sailing| sailing.code == "ERXQ" }

      expect(record).to eq(
        Freight::SailingRecord.new(
          code: "ERXQ", origin_port: "CNSHA", destination_port: "ESBCN",
          departure_date: Date.new(2022, 1, 29), arrival_date: Date.new(2022, 2, 12)
        )
      )
    end
  end

  describe "invalid feeds" do
    it "rejects text that is not JSON" do
      expect { parse("not json") }.to raise_error(InvalidFeed, /invalid JSON/)
      expect { parse("") }.to raise_error(InvalidFeed, /invalid JSON/)
    end

    it "rejects a payload that is not valid UTF-8" do
      expect { parse("{\"sailings\": \"\xFF\"}".b) }.to raise_error(InvalidFeed, /UTF-8/)
    end

    it "rejects a wrong structure" do
      expect { parse("[]") }.to raise_error(InvalidFeed, /JSON object/)
      expect { parse(JSON.generate("rates" => [], "exchange_rates" => {})) }.to raise_error(InvalidFeed, /sailings/)
      expect { parse(JSON.generate("sailings" => [], "exchange_rates" => {})) }.to raise_error(InvalidFeed, /rates/)
      expect { parse(JSON.generate("sailings" => [], "rates" => [])) }.to raise_error(InvalidFeed, /exchange_rates/)
    end
  end

  describe "rejected records" do
    def rejections_for(**sections)
      parse(feed_json(**sections)).rejections
    end

    it "rejects a sailing with an invalid port, date or date order and keeps the others" do
      parsed = parse(
        feed_json(
          sailings: [
            sailing_hash("GOOD"), sailing_hash("BADP", to: "NL"), sailing_hash("BADD", departs: "2022-13-45"),
            sailing_hash("BACK", departs: "2022-03-01", arrives: "2022-02-01")
          ]
        )
      )

      expect(parsed.sailings.map(&:code)).to eq(%w[ GOOD ])
      expect(parsed.rejections.map(&:reference)).to eq(%w[ BADP BADD BACK ])
      expect(parsed.rejections.map(&:reason)).to include(/destination_port/, /departure_date/, /before departure_date/)
    end

    it "normalizes ports" do
      parsed = parse(feed_json(sailings: [ sailing_hash("ABCD", from: " cnsha ") ]))

      expect(parsed.sailings.first.origin_port).to eq("CNSHA")
    end

    it "rejects records that are not objects or have no usable code" do
      rejected = rejections_for(sailings: [ "oops", { "origin_port" => "CNSHA" } ])

      expect(rejected.size).to eq(2)
      expect(rejected.first.reason).to eq("record must be an object")
      expect(rejected.last.reason).to be_present
    end

    it "rejects rates whose precision would change by rounding" do
      rejected = rejections_for(rates: [ rate_hash("ABCD", "12.345", "USD"), rate_hash("EFGH", "10.00", "USD") ])

      expect(rejected.map(&:reference)).to eq(%w[ ABCD ])
      expect(rejected.first.section).to eq("rates")
      expect(rejected.first.reason).to match(/decimal places/)
    end

    it "rejects rates that are not strings and malformed currencies" do
      rejected = rejections_for(rates: [ rate_hash("ABCD", 97_453, "JPY"), rate_hash("EFGH", "1.00", "US") ])

      expect(rejected.map(&:reference)).to eq(%w[ ABCD EFGH ])
    end

    it "rejects invalid exchange rates and duplicates, normalizing currency case" do
      parsed = parse(
        feed_json(
          exchange_rates: {
            "2022-02-01" => { "USD" => 1.126, "us" => 1.1, "jpy" => "130", "chf" => 0, "gbp" => 1.123456789 },
            "20220201" => { "usd" => 1.2 },
            "not-a-date" => { "usd" => 1.1 },
            "2022-02-02" => "oops"
          }
        )
      )

      expect(parsed.exchange_rates.map(&:currency)).to eq(%w[ usd ])
      expect(parsed.rejections.size).to eq(7)
    end
  end
end
