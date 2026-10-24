module Freight
  # EUR-based exchange rates keyed by date, e.g. { Date => { "usd" => BigDecimal } }.
  # A USD rate of 1.1138 means 1 EUR = 1.1138 USD, so USD to EUR divides.
  # The rate of the exact date is used, there is no carry-forward.
  class ExchangeRates
    BASE_CURRENCY = "EUR"
    DIVISION_DIGITS = 20

    def initialize(table = {})
      @table = table
    end

    def rate_for(currency, on:)
      code = currency.to_s.upcase
      return BigDecimal(1) if code == BASE_CURRENCY

      @table.dig(on, code.downcase)
    end

    # Amount in EUR, or nil when no usable exchange rate exists for that date.
    def to_eur(rate, on:)
      factor = rate_for(rate.currency, on: on)
      return nil if factor.nil? || !factor.positive?

      rate.amount.div(factor, DIVISION_DIGITS)
    end
  end
end
