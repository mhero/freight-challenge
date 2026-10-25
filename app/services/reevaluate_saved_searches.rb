# After an import, answers pending saved searches that can now be fulfilled.
# Rows are claimed with FOR UPDATE SKIP LOCKED in batches, so concurrent runs and
# retries never fulfil a search twice (the event table is unique per search too).
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
    fulfilled = 0
    last_id = 0
    loop do
      searches, count = ApplicationRecord.transaction do
        batch = SavedSearch.pending.where("id > ?", last_id).order(:id).limit(BATCH_SIZE)
                           .lock("FOR UPDATE SKIP LOCKED").to_a
        [ batch, batch.count { |search| fulfill(search) } ]
      end
      fulfilled += count
      break if searches.size < BATCH_SIZE

      last_id = searches.last.id
    end
    fulfilled
  end

  private

  def fulfill(search)
    criterion = Freight::Criteria.fetch(search.criterion)
    sailings = @repository.reachable_from(search.origin_port)
    route = Freight::RouteSearch.new(sailings)
                                .best_route(origin: search.origin_port, destination: search.destination_port, criterion: criterion)
    return false unless route

    search.update!(status: "fulfilled", fulfilled_at: Time.current, fulfilled_import_id: @feed_import.id)
    FulfillmentEvent.create!(saved_search: search, feed_import: @feed_import, payload: { "legs" => route.to_legs })
    true
  end
end
