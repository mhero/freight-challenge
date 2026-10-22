module Freight
  # Turns a route into the output format of the challenge README: one hash per leg, with the
  # leg's original rate and currency (never the EUR conversion).
  module RouteSerializer
    def self.call(route)
      route.legs.map { |leg| leg_hash(leg) }
    end

    def self.leg_hash(leg)
      {
        "origin_port" => leg.origin.code,
        "destination_port" => leg.destination.code,
        "departure_date" => leg.departure_date.iso8601,
        "arrival_date" => leg.arrival_date.iso8601,
        "sailing_code" => leg.code,
        "rate" => leg.price.formatted_amount,
        "rate_currency" => leg.price.currency.code
      }
    end
    private_class_method :leg_hash
  end
end
