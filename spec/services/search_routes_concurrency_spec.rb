require "rails_helper"

# Searches run while an import commits. Each search reads one snapshot: it sees the old data or the new
# data, never sailings of one and exchange rates of the other.
RSpec.describe SearchRoutes, "while an import commits" do
  self.use_transactional_tests = false

  let(:searcher_count) { 3 }

  before { truncate_all_tables }
  after { truncate_all_tables }

  # Old data: S1 costs 100 EUR (USD 100 at 1.0), S2 150 EUR: cheapest is S1.
  def old_feed
    feed_json(
      sailings: [ sailing_hash("S1"), sailing_hash("S2") ],
      rates: [ rate_hash("S1", "100.00", "USD"), rate_hash("S2", "150.00", "EUR") ],
      exchange_rates: usd_on("2022-02-01", 1.0)
    )
  end

  # New snapshot: the USD rate halves (S1 now 200 EUR) and S3 replaces S2: cheapest is S3.
  # Old sailings with the new rate would give S2, a third answer that no snapshot contains.
  def new_feed
    feed_json(
      sailings: [ sailing_hash("S1"), sailing_hash("S3") ],
      rates: [ rate_hash("S1", "100.00", "USD"), rate_hash("S3", "120.00", "EUR") ],
      exchange_rates: usd_on("2022-02-01", 0.5)
    )
  end

  def cheapest_codes
    described_class.call(origin: "CNSHA", destination: "NLRTM", criterion: "cheapest").route.sailing_codes
  end

  it "returns the old or the new answer, never a mix, and raises no errors" do
    ImportFeed.call(old_feed, source: "old")

    # Searchers stop after loading the sailings and before loading the exchange rates.
    loaded_sailings = Queue.new
    resume = Queue.new
    allow(ExchangeRate).to receive(:table_for).and_wrap_original do |original, *args|
      if Thread.current[:searcher]
        loaded_sailings << true
        resume.pop
      end
      original.call(*args)
    end

    searchers = Array.new(searcher_count) do
      Thread.new do
        Thread.current[:searcher] = true
        ApplicationRecord.connection_pool.with_connection { cheapest_codes }
      end
    end
    searcher_count.times { loaded_sailings.pop }

    ImportFeed.call(new_feed, source: "new")
    searcher_count.times { resume << true }
    results = searchers.map(&:value)

    expect(results).to all(eq(%w[ S1 ]))
    expect(cheapest_codes).to eq(%w[ S3 ])
  end
end
