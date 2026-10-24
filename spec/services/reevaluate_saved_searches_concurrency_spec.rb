require "rails_helper"

RSpec.describe ReevaluateSavedSearches, "with concurrent runs" do
  self.use_transactional_tests = false

  before { truncate_all_tables }
  after { truncate_all_tables }

  it "skips searches that another run has locked" do
    import = ImportFeed.call(feed_with_second_leg, source: "feed", reevaluator: nil).feed_import
    locked_search = create(:saved_search, criterion: "cheapest")
    free_search = create(:saved_search, criterion: "fastest")
    locked = Queue.new
    release = Queue.new

    holder = Thread.new do
      ApplicationRecord.connection_pool.with_connection do
        ApplicationRecord.transaction do
          SavedSearch.lock.find(locked_search.id)
          locked << true
          release.pop
        end
      end
    end
    locked.pop

    fulfilled = described_class.call(feed_import: import)
    release << true
    holder.join

    expect(fulfilled).to eq(1)
    expect(locked_search.reload.status).to eq("pending")
    expect(free_search.reload.status).to eq("fulfilled")
  end
end
