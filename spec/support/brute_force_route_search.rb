# The exhaustive search (every simple path) used as an oracle for Freight::RouteSearch in specs.
class BruteForceRouteSearch
  def initialize(sailings)
    @sailings = sailings
  end

  def best_route(origin:, destination:, criterion:)
    best = nil
    walk(origin, destination, criterion, [], [ origin ]) do |route|
      best = route if best.nil? || (criterion.sort_key(route) <=> criterion.sort_key(best)).negative?
    end
    best
  end

  private

  def walk(port, destination, criterion, legs, visited, &block)
    candidates = @sailings.select do |sailing|
      sailing.origin_port == port && (legs.empty? || sailing.departure_date >= legs.last.arrival_date)
    end
    candidates.each do |sailing|
      next if visited.include?(sailing.destination_port)

      path = legs + [ sailing ]
      if sailing.destination_port == destination
        block.call(Freight::Route.new(path))
      elsif criterion.max_legs.nil? || path.size < criterion.max_legs
        walk(sailing.destination_port, destination, criterion, path, visited + [ sailing.destination_port ], &block)
      end
    end
  end
end
