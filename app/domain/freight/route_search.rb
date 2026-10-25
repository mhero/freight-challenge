module Freight
  # Best route search: Dijkstra over sailings (not ports), ordered by the criterion's sort_key.
  #
  # - A node is a sailing. Sailing A leads to sailing B when B leaves from A's destination
  #   on or after A's arrival date (same-day connections allowed: dates only).
  # - Routes are popped from a priority queue in sort_key order, so the first route that
  #   reaches the destination is the best one and the search stops there.
  # - Each sailing is settled once. This is valid because a criterion's sort_key grows with every
  #   added leg and keeps its order when the same legs are appended (see Criteria::Base).
  # - Cycles cannot win (dropping a loop is never worse and has fewer legs), so no port tracking is needed.
  # - Departures of a port are loaded through the repository only for ports the search actually
  #   reaches, and only from the earliest arrival date seen so far (the date filter runs in SQL).
  #   A port is loaded again only when a route reaches it earlier than every previous one.
  # - A route is queued only if it beats the best route already queued for its last sailing,
  #   so the queue holds at most one useful entry per improvement, not one per edge.
  class RouteSearch
    def initialize(repository:)
      @repository = repository
    end

    def best_route(origin:, destination:, criterion:)
      return nil if origin == destination

      departures = {}
      settled = Set.new
      best_keys = {}
      queue = MinHeap.new
      departures_after(departures, origin, nil).each { |sailing| enqueue(queue, best_keys, criterion, Route.new([ sailing ])) }

      until queue.empty?
        route = queue.pop
        last = route.legs.last
        next unless settled.add?(last.code)
        return route if last.destination_port == destination
        next unless within_leg_limit?(criterion, route)

        departures_after(departures, last.destination_port, last.arrival_date).each do |sailing|
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

    # The cache keeps, per port, the date it was loaded from and the sorted departures from that date.
    # A later request for the same date or a later one is answered from the list; a request for an
    # earlier date loads the port again from that date (the date filter runs in the database).
    def departures_after(cache, port, date)
      loaded_from, list = cache[port]
      unless list && covers?(loaded_from, date)
        list = @repository.departures_from(port, on_or_after: date)
        cache[port] = [ date, list ]
      end
      return list if date.nil?

      index = list.bsearch_index { |sailing| sailing.departure_date >= date }
      index ? list[index..] : []
    end

    def covers?(loaded_from, date)
      loaded_from.nil? || (!date.nil? && date >= loaded_from)
    end
  end
end
