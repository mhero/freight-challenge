require "rails_helper"

RSpec.describe NotificationInbox do
  subject(:inbox) { described_class.new }

  def event_for(origin: "CNSHA", destination: "NLRTM", criterion: "cheapest")
    create(:fulfillment_event, saved_search: create(:saved_search, status: "fulfilled", origin_port: origin, destination_port: destination, criterion: criterion))
  end

  let!(:first) { event_for }
  let!(:second) { event_for(origin: "ESBCN", criterion: "fastest") }
  let!(:third) { event_for(destination: "BRSSZ") }

  describe "#list" do
    it "returns unacknowledged events oldest first" do
      expect(inbox.list.events).to eq([ first, second, third ])
      expect(inbox.list.next_after_id).to be_nil
    end

    it "paginates with a cursor" do
      page = inbox.list(limit: 2)

      expect(page.events).to eq([ first, second ])
      expect(page.next_after_id).to eq(second.id)
      expect(inbox.list(limit: 2, after_id: page.next_after_id).events).to eq([ third ])
    end

    it "filters by status, ports and criterion" do
      first.update!(acknowledged_at: Time.current)

      expect(inbox.list(status: "acknowledged").events).to eq([ first ])
      expect(inbox.list(status: "all").events.size).to eq(3)
      expect(inbox.list(origin: "esbcn").events).to eq([ second ])
      expect(inbox.list(destination: "BRSSZ").events).to eq([ third ])
      expect(inbox.list(criterion: "fastest").events).to eq([ second ])
    end

    it "rejects invalid status and limit" do
      expect { inbox.list(status: "weird") }.to raise_error(described_class::InvalidQuery, /status/)
      expect { inbox.list(limit: 0) }.to raise_error(described_class::InvalidQuery, /limit/)
      expect { inbox.list(limit: 501) }.to raise_error(described_class::InvalidQuery, /limit/)
    end
  end

  describe "acknowledging" do
    it "acknowledges several ids and counts only the new ones" do
      expect(inbox.acknowledge(ids: [ first.id, third.id ])).to eq(2)
      expect(inbox.acknowledge(ids: [ first.id ])).to eq(0)
      expect(inbox.list.events).to eq([ second ])
    end

    it "acknowledges everything up to an id" do
      expect(inbox.acknowledge_through(second.id)).to eq(2)
      expect(inbox.list.events).to eq([ third ])
    end
  end
end
