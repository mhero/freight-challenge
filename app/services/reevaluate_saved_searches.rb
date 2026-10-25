# After an import, answers pending saved searches that can now be fulfilled.
#
# Pending searches are grouped by origin: the reachable sailings of an origin are loaded once and every
# (destination, criterion) search of that origin runs in memory over the same data. Never one load per search.
# Rows are claimed with FOR UPDATE SKIP LOCKED in batches, so concurrent runs and retries never fulfil
# a search twice (the event table is unique per search too).
class ReevaluateSavedSearches
  BATCH_SIZE = 100

  def self.call(...)
    new(...).call
  end

  def initialize(feed_import:, repository: ActiveRecordSailingRepository.new)
    @feed_import = feed_import
    @repository = repository
  end

  # Returns the number of searches fulfilled.
  def call
    pending_origins.sum { |origin| fulfill_origin(origin) }
  end

  private

  def pending_origins
    SavedSearch.pending.distinct.order(:origin_port).pluck(:origin_port)
  end

  def fulfill_origin(origin)
    search = Freight::RouteSearch.new(@repository.reachable_from(origin))
    fulfilled = 0
    last_id = 0
    loop do
      searches, count = ApplicationRecord.transaction do
        batch = SavedSearch.pending.where(origin_port: origin).where("id > ?", last_id).order(:id).limit(BATCH_SIZE)
                           .lock("FOR UPDATE SKIP LOCKED").to_a
        [ batch, batch.count { |saved| fulfill(search, saved) } ]
      end
      fulfilled += count
      break if searches.size < BATCH_SIZE

      last_id = searches.last.id
    end
    fulfilled
  end

  def fulfill(search, saved)
    criterion = Freight::Criteria.fetch(saved.criterion)
    route = search.best_route(origin: saved.origin_port, destination: saved.destination_port, criterion: criterion)
    return false unless route

    saved.update!(status: "fulfilled", fulfilled_at: Time.current, fulfilled_import_id: @feed_import.id)
    FulfillmentEvent.create!(saved_search: saved, feed_import: @feed_import, payload: { "legs" => route.to_legs })
    true
  end
end
