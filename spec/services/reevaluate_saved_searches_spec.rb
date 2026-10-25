require "rails_helper"

RSpec.describe ReevaluateSavedSearches do
  let!(:cheapest) { create(:saved_search, criterion: "cheapest") }
  let!(:fastest) { create(:saved_search, criterion: "fastest") }
  let!(:direct) { create(:saved_search, criterion: "cheapest-direct") }

  before { ImportFeed.call(feed_without_second_leg, source: "first") }

  it "fulfils the searches a new feed makes answerable and writes one event each" do
    import = ImportFeed.call(feed_with_second_leg, source: "second").feed_import

    expect(import.stats).to be_present
    expect(cheapest.reload).to have_attributes(status: "fulfilled", fulfilled_import_id: import.id)
    expect(fastest.reload.status).to eq("fulfilled")
    expect(direct.reload.status).to eq("pending")
    expect(FulfillmentEvent.count).to eq(2)
    expect(cheapest.fulfillment_event.payload["legs"].map { |leg| leg["sailing_code"] }).to eq(%w[ ERXQ ETRG ])
  end

  it "reports how many searches an import fulfilled" do
    result = ImportFeed.call(feed_with_second_leg, source: "second")

    expect(result.fulfilled_searches).to eq(2)
  end

  it "leaves everything unfulfilled when the feed adds no route" do
    result = ImportFeed.call(feed_without_second_leg + " ", source: "same data")

    expect(result.fulfilled_searches).to eq(0)
    expect(FulfillmentEvent.count).to eq(0)
  end

  it "is safe to run again: nothing is fulfilled twice" do
    import = ImportFeed.call(feed_with_second_leg, source: "second").feed_import

    expect(described_class.call(feed_import: import)).to eq(0)
    expect(FulfillmentEvent.count).to eq(2)
  end

  it "works through several batches" do
    stub_const("ReevaluateSavedSearches::BATCH_SIZE", 1)

    result = ImportFeed.call(feed_with_second_leg, source: "second")

    expect(result.fulfilled_searches).to eq(2)
  end

  describe "data loading" do
    let(:repository) { ActiveRecordSailingRepository.new }

    before do
      allow(repository).to receive(:reachable_from).and_call_original
      create(:saved_search, origin_port: "CNSHA", destination_port: "ESBCN", criterion: "cheapest")
      create(:saved_search, origin_port: "ESBCN", destination_port: "NLRTM", criterion: "cheapest")
    end

    it "loads the reachable sailings once per distinct origin, not once per saved search" do
      import = ImportFeed.call(feed_with_second_leg, source: "second", reevaluator: nil).feed_import

      fulfilled = described_class.call(feed_import: import, repository: repository)

      expect(SavedSearch.count).to eq(5)
      expect(fulfilled).to eq(4)
      expect(repository).to have_received(:reachable_from).with("CNSHA").once
      expect(repository).to have_received(:reachable_from).with("ESBCN").once
      expect(repository).to have_received(:reachable_from).twice
    end

    it "loads each origin once even when its searches span several batches" do
      stub_const("ReevaluateSavedSearches::BATCH_SIZE", 1)
      import = ImportFeed.call(feed_with_second_leg, source: "second", reevaluator: nil).feed_import

      described_class.call(feed_import: import, repository: repository)

      expect(repository).to have_received(:reachable_from).with("CNSHA").once
    end

    it "does not load anything when nothing is pending" do
      SavedSearch.delete_all
      import = ImportFeed.call(feed_with_second_leg, source: "second", reevaluator: nil).feed_import

      described_class.call(feed_import: import, repository: repository)

      expect(repository).not_to have_received(:reachable_from)
    end
  end
end
