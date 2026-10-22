module Freight
  # Registry of the available search criteria. Adding a criterion = adding a class under
  # criteria/ and listing it in `all`; existing criteria are not modified.
  module Criteria
    def self.all
      [ CheapestDirect.new ].freeze
    end

    def self.find(name)
      key = name.to_s.strip.downcase
      all.find { |criterion| criterion.name == key } ||
        raise(Errors::UnknownCriterion, "unknown criterion: #{name.inspect}")
    end
  end
end
