module Freight
  # An amount in one currency. BigDecimal only, never floats.
  #
  # `Money.parse` is the strict boundary used for feed data (positive, no more decimals than
  # the currency allows). `Money.new` is permissive about value so that converted and summed
  # amounts keep full precision; they are used only for comparison, never printed.
  class Money < Data.define(:amount, :currency)
    DECIMAL = /\A\d+(\.\d+)?\z/

    def self.parse(text, currency_code)
      raise Errors::InvalidMoney, "amount must be a String, got #{text.class}" unless text.is_a?(String)

      currency = Currency.new(currency_code)
      cleaned = text.strip
      raise Errors::InvalidMoney, "invalid amount: #{text.inspect}" unless DECIMAL.match?(cleaned)

      amount = BigDecimal(cleaned)
      raise Errors::InvalidMoney, "amount must be greater than zero: #{text.inspect}" unless amount.positive?
      if amount != amount.round(currency.exponent)
        raise Errors::InvalidMoney, "#{text.inspect} has more than #{currency.exponent} decimals for #{currency}"
      end

      new(amount: amount, currency: currency)
    end

    def initialize(amount:, currency:)
      raise Errors::InvalidMoney, "amount must be a BigDecimal" unless amount.is_a?(BigDecimal) && amount.finite?
      raise Errors::InvalidMoney, "currency must be a Currency" unless currency.is_a?(Currency)

      super
    end

    def +(other)
      unless other.is_a?(Money) && currency == other.currency
        raise Errors::CurrencyMismatch, "cannot add #{other.inspect} to #{self}"
      end

      Money.new(amount: amount + other.amount, currency: currency)
    end

    # Amount with the currency's minor units: "589.30" for USD, "97453" for JPY.
    def formatted_amount
      exponent = currency.exponent
      # BigDecimal#round(0) returns an Integer, so wrap it to always format a BigDecimal.
      whole, fraction = BigDecimal(amount.round(exponent)).to_s("F").split(".")
      return whole if exponent.zero?

      "#{whole}.#{fraction.to_s.ljust(exponent, "0")[0, exponent]}"
    end

    def to_s = "#{formatted_amount} #{currency}"
  end
end
