module Freight
  # Depth-first search over priced sailings. Ports are expanded on demand
  # through the repository, so the whole schedule is never loaded.
  #
  # - A connection is feasible when the next departure date is on or after the
  #   previous arrival date (same-day connections allowed: dates only).
  # - No port is visited twice, so cycles cannot happen.
  # - The criterion limits the leg count, prunes hopeless partial routes and
  #   picks the best route.
  class RouteSearch
    def initialize(repository:)
      @repository = repository
    end

    def best_route(origin:, destination:, criterion:)
      explore(
        port: origin, destination: destination, criterion: criterion,
        route: nil, visited: [ origin ], best: nil
      )
    end

    private

    def explore(port:, destination:, criterion:, route:, visited:, best:)
      @repository.departures_from(port, on_or_after: route&.arrival_date).each do |sailing|
        next if visited.include?(sailing.destination_port)

        candidate = route ? route.extend_with(sailing) : Route.new([ sailing ])
        next if best && criterion.prunable?(candidate, best)

        if sailing.destination_port == destination
          best = criterion.better(best, candidate)
        elsif within_leg_limit?(criterion, candidate)
          best = explore(
            port: sailing.destination_port, destination: destination, criterion: criterion,
            route: candidate, visited: visited + [ sailing.destination_port ], best: best
          )
        end
      end
      best
    end

    def within_leg_limit?(criterion, route)
      criterion.max_legs.nil? || route.leg_count < criterion.max_legs
    end
  end
end
