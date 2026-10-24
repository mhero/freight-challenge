require "rails_helper"

RSpec.describe SeedFeed do
  it "imports the bundled sample feed by default" do
    result = described_class.call(env: {})

    expect(result.skipped).to be(false)
    expect(result.feed_import.source).to eq(SeedFeed::DEFAULT_PATH)
    expect(Sailing.count).to eq(9)
  end

  it "does nothing the second time" do
    described_class.call(env: {})

    expect(described_class.call(env: {}).skipped).to be(true)
    expect(FeedImport.count).to eq(1)
  end

  it "imports the file named by FEED_PATH instead" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "other.json")
      File.write(path, feed_json(sailings: [ sailing_hash("OTHR") ]))

      described_class.call(env: { "FEED_PATH" => path })
    end

    expect(Sailing.pluck(:sailing_code)).to eq(%w[ OTHR ])
  end

  it "falls back to the bundled feed when FEED_PATH is empty" do
    described_class.call(env: { "FEED_PATH" => "" })

    expect(Sailing.count).to eq(9)
  end

  it "can be disabled with SEED_ON_BOOT=false" do
    expect(described_class.call(env: { "SEED_ON_BOOT" => "false" })).to be_nil
    expect(FeedImport.count).to eq(0)
  end

  it "fails loudly when the configured file is missing" do
    expect { described_class.call(env: { "FEED_PATH" => "/nowhere/feed.json" }) }
      .to raise_error(ImportFeedFile::FileMissing)
  end
end
