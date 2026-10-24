require "rails_helper"

RSpec.describe SavedSearch do
  describe ".record_unfulfilled!" do
    let(:query) { { origin: "CNSHA", destination: "NLRTM", criterion: "cheapest" } }

    it "saves a pending search" do
      search = described_class.record_unfulfilled!(**query)

      expect(search).to have_attributes(origin_port: "CNSHA", destination_port: "NLRTM", criterion: "cheapest", status: "pending")
    end

    it "deduplicates by origin, destination and criterion" do
      first = described_class.record_unfulfilled!(**query)

      expect(described_class.record_unfulfilled!(**query)).to eq(first)
      expect(described_class.count).to eq(1)
      expect(described_class.record_unfulfilled!(**query, criterion: "fastest")).not_to eq(first)
    end

    it "opens a new search when the earlier one was fulfilled" do
      first = described_class.record_unfulfilled!(**query)
      first.update!(status: "fulfilled")

      expect(described_class.record_unfulfilled!(**query)).not_to eq(first)
    end
  end

  it "allows only one event per search" do
    event = create(:fulfillment_event)

    expect { within_savepoint { create(:fulfillment_event, saved_search: event.saved_search) } }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end
end
