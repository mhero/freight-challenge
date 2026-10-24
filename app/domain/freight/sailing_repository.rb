module Freight
  # What the domain needs from storage. Adapters (ActiveRecord, in-memory)
  # include this module and return priced Freight::Sailing objects only.
  module SailingRepository
    # Active, priced sailings leaving `port`, departing on or after the given date
    # (any date when nil), ordered by departure date then sailing code.
    def departures_from(_port, on_or_after: nil)
      raise NotImplementedError
    end

    # True when the port appears in any active sailing.
    def known_port?(_code)
      raise NotImplementedError
    end
  end
end
