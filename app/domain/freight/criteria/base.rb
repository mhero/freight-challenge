module Freight
  module Criteria
    # A criterion decides which routes are allowed and which one is best.
    # Subclasses define `name` and `sort_key`; the smallest key wins.
    #
    # RouteSearch relies on two properties of sort_key:
    # - appending a leg to a route always makes its key larger;
    # - if route X has a smaller key than route Y and both end with the same sailing,
    #   X plus any further legs still has a smaller key than Y plus the same legs.
    # Prices and dates never decrease along a route and every leg adds to the leg count,
    # so keys built from (price, duration, leg count, codes) satisfy both.
    class Base
      def name
        raise NotImplementedError
      end

      # Maximum number of legs: nil (no limit) or 1 (direct only).
      # Other limits would break the search's assumption that the best route to a sailing is final.
      def max_legs
        nil
      end

      def sort_key(_route)
        raise NotImplementedError
      end

      def best(routes)
        routes.min_by { |route| sort_key(route) }
      end
    end
  end
end
