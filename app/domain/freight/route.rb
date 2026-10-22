module Freight
  # An ordered list of priced legs from an origin to a destination.
  class Route < Data.define(:legs)
    def initialize(legs:)
      raise Errors::InvalidRoute, "a route needs at least one leg" if legs.nil? || legs.empty?

      super(legs: legs.dup.freeze)
    end

    def origin = legs.first.origin

    def destination = legs.last.destination

    def departure_date = legs.first.departure_date

    def arrival_date = legs.last.arrival_date

    # First departure to last arrival, layovers included (docs/data_policy.md, P2).
    def duration_days = (arrival_date - departure_date).to_i

    def leg_count = legs.size

    def direct? = leg_count == 1

    def sailing_codes = legs.map(&:code)

    def total_eur = legs.map(&:eur_price).reduce(:+)
  end
end
