require "rails_helper"

RSpec.describe ImportFeedFile do
  let(:directory) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(directory) }

  it "imports a feed file and uses the path as source" do
    path = directory.join("feed.json")
    path.write(feed_json(sailings: [ sailing_hash("ABCD") ], rates: [ rate_hash("ABCD", "1.00", "EUR") ]))

    result = described_class.call(path)

    expect(result.feed_import.source).to eq(path.to_s)
    expect(Sailing.pluck(:sailing_code)).to eq(%w[ ABCD ])
  end

  it "reads files that start with a byte order mark" do
    path = directory.join("bom.json")
    path.binwrite("\xEF\xBB\xBF".b + feed_json(sailings: [ sailing_hash("ABCD") ]).b)

    expect(described_class.call(path).skipped).to be(false)
    expect(Sailing.count).to eq(1)
  end

  it "reports a missing file" do
    expect { described_class.call(directory.join("missing.json")) }
      .to raise_error(ImportFeedFile::FileMissing, /not found/)
  end

  it "passes the reevaluator on to the import" do
    path = directory.join("feed.json")
    path.write(feed_json)
    reevaluator = ->(feed_import:) { feed_import.id }

    result = described_class.call(path, reevaluator: reevaluator)

    expect(result.fulfilled_searches).to eq(result.feed_import.id)
  end
end
