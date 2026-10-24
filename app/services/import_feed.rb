require "digest"

# Imports one MapReduce feed synchronously (CLI, entrypoint, tests or a future job).
#
# - The same file (checksum) is imported once; imports are serialized by an advisory lock.
# - Everything is written in one transaction, in batches.
# - A feed is a full snapshot: sailings missing from it become inactive, never deleted.
# - Rates are appended per import; the effective rate is the one of the import that last saw the sailing.
class ImportFeed
  BATCH_SIZE = 1_000
  LOCK_KEY = 7_314_001

  Result = Data.define(:feed_import, :skipped, :fulfilled_searches)

  def self.call(...)
    new(...).call
  end

  def initialize(payload, source:, reevaluator: ReevaluateSavedSearches)
    @payload = payload
    @source = source
    @reevaluator = reevaluator
    @checksum = Digest::SHA256.hexdigest(payload)
  end

  def call
    parsed = parse
    result = ApplicationRecord.transaction do
      acquire_lock
      existing = FeedImport.completed.find_by(checksum: @checksum)
      next Result.new(feed_import: existing, skipped: true, fulfilled_searches: 0) if existing

      Result.new(feed_import: import(parsed), skipped: false, fulfilled_searches: 0)
    end
    return result if result.skipped

    fulfilled = @reevaluator ? @reevaluator.call(feed_import: result.feed_import) : 0
    result.with(fulfilled_searches: fulfilled)
  end

  private

  def parse
    MapReduceFeed.parse(@payload)
  rescue InvalidFeed => e
    FeedImport.create!(
      source: @source, checksum: @checksum, raw_payload: @payload.scrub, status: "failed",
      error_message: e.message, started_at: Time.current, finished_at: Time.current
    )
    raise
  end

  def acquire_lock
    ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
  end

  def import(parsed)
    feed_import = FeedImport.create!(
      source: @source, checksum: @checksum, raw_payload: @payload, status: "processing", started_at: Time.current
    )
    upsert_exchange_rates(parsed.exchange_rates, feed_import)

    exchange_rates = ExchangeRate.table_for(parsed.sailings.map(&:departure_date).uniq)
    merge = FeedMerge.new(exchange_rates).call(sailing_records: parsed.sailings, rate_records: parsed.rates)

    upsert_sailings(merge.sailings, feed_import)
    priced = insert_rates(merge.resolutions, feed_import)
    deactivated = deactivate_unseen(feed_import)
    issues = record_issues(feed_import, parsed.rejections, merge.issues)

    feed_import.update!(
      status: "completed", finished_at: Time.current,
      stats: {
        "sailings" => merge.sailings.size, "priced_sailings" => priced,
        "exchange_rates" => parsed.exchange_rates.size, "deactivated_sailings" => deactivated,
        "issues" => issues.tally
      }
    )
    feed_import
  end

  def upsert_exchange_rates(records, feed_import)
    records.each_slice(BATCH_SIZE) do |slice|
      rows = slice.map { |record| { date: record.date, currency: record.currency, rate: record.rate, import_id: feed_import.id } }
      ExchangeRate.upsert_all(rows, unique_by: %i[ date currency ])
    end
  end

  def upsert_sailings(sailings, feed_import)
    sailings.each_slice(BATCH_SIZE) do |slice|
      rows = slice.map do |sailing|
        {
          sailing_code: sailing.code, origin_port: sailing.origin_port, destination_port: sailing.destination_port,
          departure_date: sailing.departure_date, arrival_date: sailing.arrival_date, active: true,
          first_import_id: feed_import.id, last_seen_import_id: feed_import.id
        }
      end
      Sailing.upsert_all(
        rows, unique_by: :sailing_code,
        update_only: %i[ origin_port destination_port departure_date arrival_date active last_seen_import_id ]
      )
    end
  end

  def insert_rates(resolutions, feed_import)
    priced = resolutions.select { |_, resolution| resolution.priced? }
    priced.each_slice(BATCH_SIZE) do |slice|
      ids = Sailing.where(sailing_code: slice.map(&:first)).pluck(:sailing_code, :id).to_h
      rows = slice.map do |code, resolution|
        { sailing_id: ids.fetch(code), import_id: feed_import.id,
          amount: resolution.rate.amount_text, currency: resolution.rate.currency }
      end
      Rate.insert_all!(rows)
    end
    priced.size
  end

  def deactivate_unseen(feed_import)
    Sailing.where(active: true).where.not(last_seen_import_id: feed_import.id)
           .update_all(active: false, updated_at: Time.current)
  end

  def record_issues(feed_import, rejections, merge_issues)
    rows = rejections.map do |rejection|
      { kind: "rejected_record", reference: rejection.reference, reason: rejection.reason,
        details: { "section" => rejection.section, "raw" => rejection.raw } }
    end
    rows += merge_issues.map { |issue| { kind: issue.kind, reference: issue.reference, reason: issue.reason, details: issue.details } }
    rows.each_slice(BATCH_SIZE) do |slice|
      ImportIssue.insert_all!(slice.map { |row| row.merge(feed_import_id: feed_import.id) })
    end
    rows.map { |row| row[:kind] }
  end
end
