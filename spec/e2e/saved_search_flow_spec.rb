require "rails_helper"

RSpec.describe "saved search flow through the CLI" do
  let(:directory) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(directory) }

  it "saves an unanswerable search, fulfils it with a second feed and notifies once" do
    ImportFeed.call(feed_without_second_leg, source: "first")

    first = run_cli(stdin: "CNSHA\nNLRTM\ncheapest\n")
    expect([ first.exit_code, first.stdout ]).to eq([ 0, "[]\n" ])
    expect(SavedSearch.pending.count).to eq(1)
    expect(run_cli("notifications", "list").json["notifications"]).to be_empty

    second_feed = directory.join("second.json")
    second_feed.write(feed_with_second_leg)
    import = run_cli("import", second_feed.to_s)
    expect(import.json).to include("fulfilled_searches" => 1)

    listed = run_cli("notifications", "list").json
    notification = listed["notifications"].sole
    expect(notification).to include("origin_port" => "CNSHA", "destination_port" => "NLRTM", "criterion" => "cheapest")
    expect(notification["route"].map { |leg| leg["sailing_code"] }).to eq(%w[ ERXQ ETRG ])

    expect(run_cli(stdin: "CNSHA\nNLRTM\ncheapest\n").json.size).to eq(2)

    expect(run_cli("notifications", "ack", notification["id"].to_s).json).to eq("acknowledged" => 1)
    expect(run_cli("notifications", "list").json["notifications"]).to be_empty
    expect(run_cli("notifications", "list", "--status", "acknowledged").json["notifications"].size).to eq(1)
  end

  it "saves searches for unknown ports too, once per query" do
    ImportFeed.call(feed_without_second_leg, source: "first")

    2.times { run_cli(stdin: "CNSHA\nZZZZZ\nfastest\n") }

    expect(SavedSearch.pending.pluck(:origin_port, :destination_port, :criterion)).to eq([ %w[ CNSHA ZZZZZ fastest ] ])
  end

  it "does not save a search that has an answer" do
    ImportFeed.call(feed_with_second_leg, source: "second")

    run_cli(stdin: "CNSHA\nNLRTM\ncheapest\n")

    expect(SavedSearch.count).to eq(0)
  end
end
