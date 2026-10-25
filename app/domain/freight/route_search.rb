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
  # - Departures of a port are loaded once per search through the repository, and only for
  #   ports the search actually reaches.
  class RouteSearch
    def initialize(repository:)
      @repository = repository
    end

    def best_route(origin:, destination:, criterion:)
      return nil if origin == destination

      departures = {}
      settled = Set.new
      queue = MinHeap.new
      departures_after(departures, origin, nil).each { |sailing| enqueue(queue, criterion, Route.new([ sailing ])) }

      until queue.empty?
        route = queue.pop
        last = route.legs.last
        next unless settled.add?(last.code)
        return route if last.destination_port == destination
        next unless within_leg_limit?(criterion, route)

        departures_after(departures, last.destination_port, last.arrival_date).each do |sailing|
          enqueue(queue, criterion, route.extend_with(sailing))
        end
      end
      nil
    end

    private

    def enqueue(queue, criterion, route)
      queue.push(criterion.sort_key(route), route)
    end

    def within_leg_limit?(criterion, route)
      criterion.max_legs.nil? || route.leg_count < criterion.max_legs
    end

    # One repository call per port and search; the date filter runs on the sorted list.
    def departures_after(cache, port, date)
      all = (cache[port] ||= @repository.departures_from(port))
      return all if date.nil?

      index = all.bsearch_index { |sailing| sailing.departure_date >= date }
      index ? all[index..] : []
    end
  end
end
