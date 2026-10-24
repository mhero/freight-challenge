module Freight
  # A sailing as described by a feed, before it has a price.
  SailingRecord = Data.define(:code, :origin_port, :destination_port, :departure_date, :arrival_date)
end
