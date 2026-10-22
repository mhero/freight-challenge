module Freight
  module Criteria
    # PLS-0001: the cheapest single-leg route. Ties: earlier arrival, then sailing code.
    class CheapestDirect < Base
      NAME = "cheapest-direct".freeze

      private

      def candidate_routes(catalogue, origin, destination)
        catalogue.sailings_between(origin, destination).map { |sailing| Route.new(legs: [ sailing ]) }
      end

      def sort_key(route)
        [ route.total_eur.amount, route.arrival_date, route.sailing_codes ]
      end
    end
  end
end
