module Freight
  module Criteria
    # PLS-0001: lowest total EUR price using a single sailing.
    # Ties: fewer legs, earlier arrival, then sailing codes ascending.
    class CheapestDirect < Base
      def name
        "cheapest-direct"
      end

      def max_legs
        1
      end

      def sort_key(route)
        [ route.total_eur, route.leg_count, route.arrival_date, route.sailing_codes ]
      end

      def prunable?(partial, best)
        partial.total_eur > best.total_eur
      end
    end
  end
end
