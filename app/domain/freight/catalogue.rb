module Freight
  # The searchable set of priced sailings, plus the data-quality issues found while building it.
  # Sailings that could not be priced are not in here, so no criterion can ever return them.
  class Catalogue
    attr_reader :priced_sailings, :issues

    def initialize(priced_sailings:, issues: [])
      @priced_sailings = priced_sailings.dup.freeze
      @issues = issues.dup.freeze
      @by_route = @priced_sailings.group_by { |sailing| [ sailing.origin, sailing.destination ] }.freeze
    end

    def sailings_between(origin, destination)
      @by_route.fetch([ PortCode.new(origin), PortCode.new(destination) ], [])
    end
  end
end
