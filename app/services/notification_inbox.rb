# Pull side of the outbox: list fulfillment events (paginated, filterable) and acknowledge them.
class NotificationInbox
  class InvalidQuery < Freight::Error; end

  DEFAULT_LIMIT = 50
  MAX_LIMIT = 500
  STATUSES = %w[ unacknowledged acknowledged all ].freeze

  Page = Data.define(:events, :next_after_id)

  def list(status: "unacknowledged", after_id: 0, limit: DEFAULT_LIMIT, origin: nil, destination: nil, criterion: nil)
    raise InvalidQuery, "status must be one of: #{STATUSES.join(", ")}" unless STATUSES.include?(status)
    raise InvalidQuery, "limit must be between 1 and #{MAX_LIMIT}" unless (1..MAX_LIMIT).cover?(limit)

    scope = filter_status(FulfillmentEvent.joins(:saved_search).includes(:saved_search), status)
    scope = scope.where(saved_searches: { origin_port: Freight::PortCode.normalize(origin) }) if origin
    scope = scope.where(saved_searches: { destination_port: Freight::PortCode.normalize(destination) }) if destination
    scope = scope.where(saved_searches: { criterion: criterion }) if criterion

    rows = scope.where("fulfillment_events.id > ?", after_id).order(:id).limit(limit + 1).to_a
    Page.new(events: rows.first(limit), next_after_id: rows.size > limit ? rows[limit - 1].id : nil)
  end

  def acknowledge(ids:)
    mark_acknowledged(FulfillmentEvent.where(id: ids))
  end

  def acknowledge_through(id)
    mark_acknowledged(FulfillmentEvent.where("id <= ?", id))
  end

  private

  def filter_status(scope, status)
    case status
    when "unacknowledged" then scope.unacknowledged
    when "acknowledged" then scope.acknowledged
    else scope
    end
  end

  def mark_acknowledged(scope)
    now = Time.current
    scope.unacknowledged.update_all(acknowledged_at: now, updated_at: now)
  end
end
