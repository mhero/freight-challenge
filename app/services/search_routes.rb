# Finds the best route for a query. Ports are normalized and validated here so
# every interface (CLI today, others later) applies the same rules.
class SearchRoutes
  Result = Data.define(:route, :warnings, :saved_search)

  def self.call(...)
    new.call(...)
  end

  def initialize(repository: ActiveRecordSailingRepository.new)
    @repository = repository
  end

  def call(origin:, destination:, criterion:)
    origin = valid_port(origin, "origin")
    destination = valid_port(destination, "destination")
    criterion = Freight::Criteria.fetch(criterion.to_s.strip.downcase)

    route = Freight::RouteSearch.new(repository: @repository)
                                .best_route(origin: origin, destination: destination, criterion: criterion)
    return Result.new(route: route, warnings: [], saved_search: nil) if route

    saved = SavedSearch.record_unfulfilled!(origin: origin, destination: destination, criterion: criterion.name)
    Result.new(route: nil, warnings: unknown_port_warnings(origin, destination), saved_search: saved)
  end

  private

  def valid_port(value, role)
    code = Freight::PortCode.normalize(value)
    raise Freight::InvalidPort, "invalid #{role} port #{value.to_s.strip.inspect}, expected two letters and three letters or digits" unless Freight::PortCode.valid?(code)

    code
  end

  def unknown_port_warnings(*ports)
    ports.uniq.reject { |port| @repository.known_port?(port) }.map { |port| "unknown port #{port}" }
  end
end
