require "rails_helper"

RSpec.describe ImportFeed, "with concurrent imports" do
  self.use_transactional_tests = false

  before { truncate_all_tables }
  after { truncate_all_tables }

  it "creates no duplicates when two imports of the same feed run at the same time" do
    payload = sample_feed

    results = 2.times.map do
      Thread.new do
        ApplicationRecord.connection_pool.with_connection { described_class.call(payload, source: "thread") }
      end
    end.map(&:value)

    expect(results.map(&:skipped)).to contain_exactly(true, false)
    expect(FeedImport.completed.count).to eq(1)
    expect(Sailing.count).to eq(9)
    expect(Rate.count).to eq(9)
    expect(ExchangeRate.count).to eq(14)
    expect(ImportIssue.count).to eq(1)
  end
end
