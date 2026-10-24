module Freight
  module Criteria
    # A criterion decides which routes are allowed and which one is best.
    # Subclasses define `name` and `sort_key`; the smallest key wins.
    class Base
      def name
        raise NotImplementedError
      end

      # Maximum number of legs, nil for no limit.
      def max_legs
        nil
      end

      def sort_key(_route)
        raise NotImplementedError
      end

      # True when a partial route can no longer beat `best` (used to prune the search).
      def prunable?(_partial, _best)
        false
      end

      def best(routes)
        routes.min_by { |route| sort_key(route) }
      end

      def better(current, candidate)
        return candidate if current.nil?

        sort_key(candidate) < sort_key(current) ? candidate : current
      end
    end
  end
end
