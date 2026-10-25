module Freight
  module Criteria
    # WRT-0002: lowest total EUR price over any number of legs.
    # Ties: fewer legs, earlier arrival, then sailing codes ascending.
    class Cheapest < Base
      def name
        "cheapest"
      end

      def sort_key(route)
        [ route.total_eur, route.leg_count, route.arrival_date, route.sailing_codes ]
      end
    end
  end
end
