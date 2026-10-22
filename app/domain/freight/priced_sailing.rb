require "forwardable"

module Freight
  # A sailing with its resolved rate. `price` is the original amount and currency (what gets
  # printed); `eur_price` is the EUR equivalent at full precision (used only for comparison).
  class PricedSailing < Data.define(:sailing, :price, :eur_price)
    extend Forwardable

    def_delegators :sailing, :code, :origin, :destination, :departure_date, :arrival_date, :duration_days
  end
end
