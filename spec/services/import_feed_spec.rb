require "rails_helper"

RSpec.describe ImportFeed do
  def import(payload, **options)
    described_class.call(payload, source: "spec", **options)
  end

  def issues(kind)
    ImportIssue.where(kind: kind)
  end

  def departures(port = "CNSHA")
    ActiveRecordSailingRepository.new.departures_from(port)
  end

  describe "the sample feed" do
    let!(:result) { import(sample_feed) }

    it "stores the sailings, the winning rates and the exchange rates" do
      expect(result.skipped).to be(false)
      expect(Sailing.count).to eq(9)
      expect(Rate.count).to eq(9)
      expect(ExchangeRate.count).to eq(14)
      expect(Sailing.pluck(:first_import_id, :last_seen_import_id).uniq).to eq([ [ result.feed_import.id ] * 2 ])
    end

    it "records the import with its raw payload, checksum and statistics" do
      feed_import = result.feed_import

      expect(feed_import).to have_attributes(status: "completed", source: "spec", raw_payload: sample_feed)
      expect(feed_import.checksum).to eq(Digest::SHA256.hexdigest(sample_feed))
      expect(feed_import.finished_at).to be_present
      expect(feed_import.stats).to include("sailings" => 9, "priced_sailings" => 9, "exchange_rates" => 14)
    end

    it "keeps the highest MNOP rate and records the discarded one" do
      mnop = Rate.joins(:sailing).find_by(sailings: { sailing_code: "MNOP" })
      issue = issues("rate_conflict").sole

      expect(mnop).to have_attributes(amount: "812.00", currency: "USD")
      expect(issue.reference).to eq("MNOP")
      expect(issue.details["discarded"]).to eq([ { "amount" => "456.78", "currency" => "USD" } ])
      expect(issue.feed_import).to eq(result.feed_import)
    end

    it "makes every sailing searchable with the rate as received" do
      codes = departures.map(&:code)

      expect(codes).to match_array(%w[ ERXQ QRST MNOP IJKL ABCD EFGH ])
      expect(departures.find { |sailing| sailing.code == "IJKL" }.rate.amount_text).to eq("97453")
    end

    it "is a no-op when the same file is imported again" do
      again = import(sample_feed)

      expect(again.skipped).to be(true)
      expect(again.feed_import).to eq(result.feed_import)
      expect(FeedImport.count).to eq(1)
      expect(Rate.count).to eq(9)
      expect(ImportIssue.count).to eq(1)
    end

  end

  describe "batching" do
    it "writes the same data with small batches" do
      stub_const("ImportFeed::BATCH_SIZE", 2)

      import(sample_feed)

      expect(Sailing.count).to eq(9)
      expect(Rate.count).to eq(9)
      expect(ExchangeRate.count).to eq(14)
      expect(ImportIssue.count).to eq(1)
    end
  end

  describe "snapshot imports" do
    let(:first_feed) do
      feed_json(
        sailings: [ sailing_hash("KEEP"), sailing_hash("GONE") ],
        rates: [ rate_hash("KEEP", "10.00", "USD"), rate_hash("GONE", "20.00", "USD") ],
        exchange_rates: usd_on("2022-02-01")
      )
    end
    let(:second_feed) do
      feed_json(
        sailings: [ sailing_hash("KEEP"), sailing_hash("NEWX") ],
        rates: [ rate_hash("KEEP", "11.00", "USD"), rate_hash("NEWX", "30.00", "USD") ],
        exchange_rates: usd_on("2022-02-01")
      )
    end

    it "marks sailings missing from the new feed inactive instead of deleting them" do
      first = import(first_feed).feed_import
      second = import(second_feed).feed_import

      gone = Sailing.find_by!(sailing_code: "GONE")
      expect(gone).to have_attributes(active: false, last_seen_import_id: first.id)
      expect(Sailing.find_by!(sailing_code: "KEEP")).to have_attributes(active: true, first_import_id: first.id, last_seen_import_id: second.id)
      expect(Sailing.find_by!(sailing_code: "NEWX")).to have_attributes(active: true, first_import_id: second.id)
      expect(departures.map(&:code)).to eq(%w[ KEEP NEWX ])
    end

    it "appends rates and resolves the effective rate from the latest import" do
      import(first_feed)
      import(second_feed)

      keep = Sailing.find_by!(sailing_code: "KEEP")
      expect(keep.rates.order(:import_id).pluck(:amount)).to eq(%w[ 10.00 11.00 ])
      expect(departures.find { |sailing| sailing.code == "KEEP" }.rate.amount_text).to eq("11.00")
    end

    it "reactivates a sailing that appears again" do
      import(first_feed)
      import(second_feed)
      import(first_feed + " ")

      expect(Sailing.find_by!(sailing_code: "GONE")).to be_active
      expect(Sailing.find_by!(sailing_code: "NEWX")).not_to be_active
    end
  end

  describe "data quality" do
    it "excludes a sailing whose conflicting candidate cannot be converted" do
      payload = feed_json(
        sailings: [ sailing_hash("ABCD") ],
        rates: [ rate_hash("ABCD", "10.00", "USD"), rate_hash("ABCD", "10.00", "CHF") ],
        exchange_rates: usd_on("2022-02-01")
      )

      import(payload)

      expect(Sailing.find_by!(sailing_code: "ABCD")).to be_active
      expect(Rate.count).to eq(0)
      expect(issues("rate_conflict").sole.reason).to include("no exchange rate for CHF")
      expect(departures).to be_empty
    end

    it "excludes sailings without an exchange rate for their departure date or without a rate" do
      payload = feed_json(
        sailings: [ sailing_hash("NOFX", departs: "2022-02-02"), sailing_hash("NORT") ],
        rates: [ rate_hash("NOFX", "10.00", "USD") ],
        exchange_rates: usd_on("2022-02-01")
      )

      import(payload)

      expect(issues("unpriced").order(:reference).pluck(:reference, :reason)).to eq(
        [ [ "NOFX", "no exchange rate for USD on 2022-02-02" ], [ "NORT", "no rate in feed" ] ]
      )
      expect(departures).to be_empty
    end

    it "rejects a rate that rounding would change and records it" do
      payload = feed_json(
        sailings: [ sailing_hash("ABCD") ], rates: [ rate_hash("ABCD", "12.345", "USD") ],
        exchange_rates: usd_on("2022-02-01")
      )

      import(payload)

      rejected = issues("rejected_record").sole
      expect(rejected.reference).to eq("ABCD")
      expect(rejected.details["section"]).to eq("rates")
      expect(Rate.count).to eq(0)
    end

    it "excludes a sailing code that appears with different dates and deactivates an earlier version" do
      import(feed_json(sailings: [ sailing_hash("ABCD") ], rates: [ rate_hash("ABCD", "1.00", "EUR") ]))
      conflicting = feed_json(
        sailings: [ sailing_hash("ABCD"), sailing_hash("ABCD", arrives: "2022-03-09"), sailing_hash("OKAY") ],
        rates: [ rate_hash("ABCD", "1.00", "EUR"), rate_hash("OKAY", "1.00", "EUR") ]
      )

      import(conflicting)

      expect(issues("sailing_conflict").sole.reference).to eq("ABCD")
      expect(Sailing.find_by!(sailing_code: "ABCD")).not_to be_active
      expect(departures.map(&:code)).to eq(%w[ OKAY ])
    end

    it "records rates that belong to no sailing" do
      import(feed_json(sailings: [], rates: [ rate_hash("GHOST", "1.00", "EUR") ]))

      expect(issues("orphan_rate").sole.reference).to eq("GHOST")
    end

    it "collapses identical duplicates without reporting them" do
      payload = feed_json(
        sailings: [ sailing_hash("ABCD"), sailing_hash("ABCD") ],
        rates: [ rate_hash("ABCD", "1.00", "EUR"), rate_hash("ABCD", "1.00", "EUR") ]
      )

      import(payload)

      expect(Sailing.count).to eq(1)
      expect(Rate.count).to eq(1)
      expect(ImportIssue.count).to eq(0)
    end

    it "keeps the rejected records of an otherwise valid feed in the import record" do
      import(feed_json(sailings: [ sailing_hash("GOOD"), sailing_hash("BADP", to: "NL") ]))

      expect(Sailing.pluck(:sailing_code)).to eq(%w[ GOOD ])
      expect(issues("rejected_record").sole).to have_attributes(reference: "BADP")
    end
  end

  describe "invalid feeds" do
    it "records a failed import, raises and leaves the data untouched" do
      import(sample_feed)

      expect { import("not json") }.to raise_error(InvalidFeed)

      failed = FeedImport.find_by!(status: "failed")
      expect(failed.error_message).to match(/invalid JSON/)
      expect(failed.raw_payload).to eq("not json")
      expect(Sailing.active.count).to eq(9)
    end

    it "can be tried again" do
      2.times { expect { import("not json") }.to raise_error(InvalidFeed) }

      expect(FeedImport.where(status: "failed").count).to eq(2)
    end
  end

  describe "saved search hook" do
    it "calls the reevaluator after the import and reports how many searches were fulfilled" do
      calls = []
      reevaluator = lambda do |feed_import:|
        calls << feed_import
        3
      end

      result = import(sample_feed, reevaluator: reevaluator)

      expect(calls).to eq([ result.feed_import ])
      expect(result.fulfilled_searches).to eq(3)
    end

    it "does not call it when the feed was already imported" do
      import(sample_feed)
      reevaluator = ->(feed_import:) { raise "must not run for #{feed_import.id}" }

      expect(import(sample_feed, reevaluator: reevaluator).skipped).to be(true)
    end
  end
end
