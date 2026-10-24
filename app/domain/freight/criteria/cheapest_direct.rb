module Freight
  module Criteria
    # PLS-0001: the cheapest route restricted to a single sailing.
    class CheapestDirect < Cheapest
      def name
        "cheapest-direct"
      end

      def max_legs
        1
      end
    end
  end
end
