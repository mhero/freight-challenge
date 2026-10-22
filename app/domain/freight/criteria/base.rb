module Freight
  module Criteria
    # Template for a criterion: a criterion decides which routes are candidates and how they are
    # ranked. The best route is the candidate with the smallest sort key, so ties are broken
    # deterministically by the trailing elements of the key.
    class Base
      def name = self.class::NAME

      # Returns the best Route, or nil when there is no candidate.
      def best_route(catalogue, origin:, destination:)
        candidate_routes(catalogue, origin, destination).min_by { |route| sort_key(route) }
      end

      private

      def candidate_routes(_catalogue, _origin, _destination)
        raise NotImplementedError, "#{self.class} must implement #candidate_routes"
      end

      def sort_key(_route)
        raise NotImplementedError, "#{self.class} must implement #sort_key"
      end
    end
  end
end
