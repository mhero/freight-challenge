require "rails_helper"

RSpec.describe "database constraints" do
  let(:import) { create(:feed_import) }

  def sailing_row(overrides = {})
    {
      sailing_code: "ABCD", origin_port: "CNSHA", destination_port: "NLRTM",
      departure_date: Date.new(2022, 2, 1), arrival_date: Date.new(2022, 3, 1), active: true,
      first_import_id: import.id, last_seen_import_id: import.id
    }.merge(overrides)
  end

  it "keeps sailing codes unique" do
    Sailing.insert_all!([ sailing_row ])

    expect { within_savepoint { Sailing.insert_all!([ sailing_row ]) } }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects a sailing that arrives before it departs" do
    row = sailing_row(arrival_date: Date.new(2022, 1, 1))

    expect { within_savepoint { Sailing.insert_all!([ row ]) } }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "requires the import that produced a sailing" do
    row = sailing_row(first_import_id: 0)

    expect { within_savepoint { Sailing.insert_all!([ row ]) } }.to raise_error(ActiveRecord::InvalidForeignKey)
  end

  it "keeps one rate per sailing and import" do
    sailing = create(:sailing)
    row = { sailing_id: sailing.id, import_id: sailing.last_seen_import_id, amount: "1.00", currency: "EUR" }
    Rate.insert_all!([ row ])

    expect { within_savepoint { Rate.insert_all!([ row ]) } }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "stores rate currencies in uppercase and exchange rate currencies in lowercase" do
    sailing = create(:sailing)
    bad_rate = { sailing_id: sailing.id, import_id: import.id, amount: "1.00", currency: "usd" }
    bad_exchange_rate = { date: Date.new(2022, 2, 1), currency: "USD", rate: 1.1, import_id: import.id }

    expect { within_savepoint { Rate.insert_all!([ bad_rate ]) } }.to raise_error(ActiveRecord::CheckViolation)
    expect { within_savepoint { ExchangeRate.insert_all!([ bad_exchange_rate ]) } }.to raise_error(ActiveRecord::CheckViolation)
  end

  it "keeps one exchange rate per date and currency and requires a positive value" do
    create(:exchange_rate, date: Date.new(2022, 2, 1), currency: "usd")

    expect { within_savepoint { create(:exchange_rate, date: Date.new(2022, 2, 1), currency: "usd") } }
      .to raise_error(ActiveRecord::RecordNotUnique)
    expect { within_savepoint { create(:exchange_rate, currency: "jpy", rate: 0) } }
      .to raise_error(ActiveRecord::CheckViolation)
  end

  it "allows one completed import per checksum but several failed attempts" do
    create(:feed_import, checksum: "abc", status: "completed")
    create(:feed_import, checksum: "abc", status: "failed")
    create(:feed_import, checksum: "abc", status: "failed")

    expect { within_savepoint { create(:feed_import, checksum: "abc", status: "completed") } }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "only accepts known import statuses and issue kinds" do
    expect { within_savepoint { FeedImport.insert_all!([ { source: "x", checksum: "z", status: "weird", raw_payload: "{}", started_at: Time.current } ]) } }
      .to raise_error(ActiveRecord::CheckViolation)
    expect { within_savepoint { ImportIssue.insert_all!([ { feed_import_id: import.id, kind: "weird", reason: "x", created_at: Time.current } ]) } }
      .to raise_error(ActiveRecord::CheckViolation)
  end
end
