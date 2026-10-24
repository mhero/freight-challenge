require "rails_helper"

RSpec.describe FreightCli::NotificationsCommand do
  let!(:events) { Array.new(3) { create(:fulfillment_event) } }

  it "lists with pagination options" do
    run = run_cli("notifications", "list", "--limit", "2")

    expect(run.exit_code).to eq(0)
    expect(run.json["notifications"].map { |event| event["id"] }).to eq(events.first(2).map(&:id))
    expect(run.json["next_after_id"]).to eq(events.second.id)

    after = run_cli("notifications", "list", "--limit", "2", "--after-id", events.second.id.to_s)
    expect(after.json["notifications"].map { |event| event["id"] }).to eq([ events.third.id ])
    expect(after.json["next_after_id"]).to be_nil
  end

  it "acknowledges several ids" do
    run = run_cli("notifications", "ack", events.first.id.to_s, events.third.id.to_s)

    expect(run.json).to eq("acknowledged" => 2)
    expect(FulfillmentEvent.unacknowledged.pluck(:id)).to eq([ events.second.id ])
  end

  it "acknowledges everything up to an id" do
    run = run_cli("notifications", "ack", "--through", events.second.id.to_s)

    expect(run.json).to eq("acknowledged" => 2)
  end

  it "reports usage and invalid values as client errors" do
    expect(run_cli("notifications").error).to include("code" => 400)
    expect(run_cli("notifications", "ack").error).to include("code" => 400)
    expect(run_cli("notifications", "ack", "1", "--through", "2").error).to include("code" => 400)
    expect(run_cli("notifications", "ack", "abc").error).to include("code" => 400)
    expect(run_cli("notifications", "list", "--limit", "x").error).to include("code" => 400)
    expect(run_cli("notifications", "list", "--bogus").exit_code).to eq(2)
    expect(run_cli("notifications", "list", "--status", "weird").error).to include("code" => 422)
  end
end
