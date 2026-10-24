module Freight
  # One or more consecutive sailings (legs) from an origin to a destination.
  class Route
    attr_reader :legs

    def initialize(legs)
      @legs = legs.freeze
    end

    def origin_port
      legs.first.origin_port
    end

    def destination_port
      legs.last.destination_port
    end

    def departure_date
      legs.first.departure_date
    end

    def arrival_date
      legs.last.arrival_date
    end

    # First departure to last arrival, layovers included.
    def duration_days
      (arrival_date - departure_date).to_i
    end

    def total_eur
      legs.sum(BigDecimal(0), &:price_eur)
    end

    def leg_count
      legs.size
    end

    def sailing_codes
      legs.map(&:code)
    end

    def to_legs
      legs.map(&:to_leg)
    end

    def extend_with(sailing)
      self.class.new(legs + [ sailing ])
    end
  end
end
