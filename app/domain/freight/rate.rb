module Freight
  # A price as received: the amount text is kept untouched for output.
  # Precision is validated by value, nothing is ever rounded.
  class Rate < Data.define(:amount_text, :currency)
    AMOUNT_FORMAT = /\A\d+(\.\d+)?\z/
    CURRENCY_FORMAT = /\A[A-Z]{3}\z/

    def self.parse(amount_text, currency)
      code = currency.to_s.strip.upcase
      raise InvalidRate, "invalid currency #{currency.inspect}" unless CURRENCY_FORMAT.match?(code)
      unless amount_text.is_a?(String) && AMOUNT_FORMAT.match?(amount_text)
        raise InvalidRate, "invalid amount #{amount_text.inspect}"
      end

      rate = new(amount_text: amount_text, currency: code)
      unless rate.amount == rate.amount.round(rate.places)
        raise InvalidRate, "amount #{amount_text} exceeds #{rate.places} decimal places for #{code}"
      end

      rate
    end

    def amount
      BigDecimal(amount_text)
    end

    def places
      CurrencyPrecision.places_for(currency)
    end
  end
end
