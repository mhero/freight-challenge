module Freight
  # Best route search over sailings already loaded in memory (see SailingRepository#reachable_from).
  # Dijkstra over sailings, ordered by the criterion's sort_key. The search itself never touches storage.
  #
  # Why a node is a sailing and not a port: connections depend on time, so a port has no single best label.
  # A cheap but late arrival at a port can lose to a costlier but earlier one, because the earlier one
  # allows more onward sailings. A sailing, in contrast, fixes its own arrival date. Two routes that end
  # with the same sailing therefore allow exactly the same continuations and differ only in accumulated
  # cost (or elapsed time). Since a criterion's sort_key grows with every added leg and keeps its order when
  # the same legs are appended (see Criteria::Base), the best route to a sailing is final once popped.
  # The equivalence spec checks this against an exhaustive search.
  #
  # - A sailing A leads to sailing B when B leaves from A's destination on or after A's arrival date
  #   (same-day connections allowed: the data only has dates).
  # - Routes are popped from a priority queue in sort_key order, so the first route that reaches the
  #   destination is the best one and the search stops there. The result is exact: no leg cap, no horizon.
  # - Cycles cannot win (dropping a loop is never worse and has fewer legs), so no port tracking is needed.
  # - A route is queued only if it beats the best route already queued for its last sailing.
  class RouteSearch
    NO_SAILINGS = [].freeze

    def initialize(sailings)
      @departures = sailings.group_by(&:origin_port).transform_values do |list|
        list.sort_by { |sailing| [ sailing.departure_date, sailing.code ] }.freeze
      end
    end

    def best_route(origin:, destination:, criterion:)
      return nil if origin == destination

      settled = Set.new
      best_keys = {}
      queue = MinHeap.new
      each_departure(origin, nil) { |sailing| enqueue(queue, best_keys, criterion, Route.new([ sailing ])) }

      until queue.empty?
        route = queue.pop
        last = route.legs.last
        next unless settled.add?(last.code)
        return route if last.destination_port == destination
        next unless within_leg_limit?(criterion, route)

        each_departure(last.destination_port, last.arrival_date) do |sailing|
          enqueue(queue, best_keys, criterion, route.extend_with(sailing))
        end
      end
      nil
    end

    private

    # Skips routes that cannot beat the best one already queued for the same last sailing.
    def enqueue(queue, best_keys, criterion, route)
      code = route.legs.last.code
      key = criterion.sort_key(route)
      known = best_keys[code]
      return if known && (key <=> known) >= 0

      best_keys[code] = key
      queue.push(key, route)
    end

    def within_leg_limit?(criterion, route)
      criterion.max_legs.nil? || route.leg_count < criterion.max_legs
    end

    # Yields the departures of `port` on or after `date` (all of them when nil), in departure order.
    def each_departure(port, date)
      list = @departures.fetch(port, NO_SAILINGS)
      first = date ? list.bsearch_index { |sailing| sailing.departure_date >= date } : 0
      return unless first

      (first...list.size).each { |index| yield list[index] }
    end
  end
end
