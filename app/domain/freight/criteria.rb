module Freight
  # Registry of the search criteria. A new criterion is a new class under
  # Freight::Criteria plus one entry here; existing criteria are not touched.
  module Criteria
    def self.all
      [ CheapestDirect, Cheapest, Fastest ].map(&:new)
    end

    def self.names
      all.map(&:name)
    end

    def self.fetch(name)
      all.find { |criterion| criterion.name == name.to_s } ||
        raise(UnknownCriterion, "unknown criterion #{name.to_s.inspect}, expected one of: #{names.join(", ")}")
    end
  end
end
