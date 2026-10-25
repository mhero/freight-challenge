module Freight
  # What the domain needs from storage. Adapters (ActiveRecord, in-memory)
  # include this module and return priced Freight::Sailing objects only.
  module SailingRepository
    # Every active, priced sailing reachable from `origin` through time-feasible connections
    # (next departure date >= previous arrival date), with its EUR price for comparison.
    # Implementations must use a constant number of queries, whatever the path length.
    def reachable_from(_origin)
      raise NotImplementedError
    end

    # The given port codes that appear in an active sailing (one query for all of them).
    def known_ports(_codes)
      raise NotImplementedError
    end
  end
end
