module Freight
  module Criteria
    # TST-0003: shortest journey from first departure to last arrival, layovers included.
    # (Alternative definition, summing leg durations only, is a PO question.)
    # Ties: lower total EUR, fewer legs, then sailing codes ascending.
    class Fastest < Base
      def name
        "fastest"
      end

      def sort_key(route)
        [ route.duration_days, route.total_eur, route.leg_count, route.sailing_codes ]
      end
    end
  end
end
