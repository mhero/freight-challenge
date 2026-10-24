module Freight
  # Decimal places allowed per currency. Anything not listed uses DEFAULT_PLACES.
  module CurrencyPrecision
    DEFAULT_PLACES = 2
    PLACES = { "JPY" => 0, "USD" => 2, "EUR" => 2 }.freeze

    def self.places_for(currency)
      PLACES.fetch(currency.to_s.upcase, DEFAULT_PLACES)
    end
  end
end
