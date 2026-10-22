module Freight
  # EUR-based exchange rates per date: { Date => { Currency => BigDecimal } }.
  # A rate of 1.1138 for USD means 1 EUR = 1.1138 USD, so converting to EUR means dividing.
  # The date is looked up exactly; there is no carry-forward from nearby dates.
  class ExchangeRates
    DIVISION_DIGITS = 20

    def initialize(table)
      @table = table.each_with_object({}) do |(date, rates), by_date|
        by_date[date] = rates.each_with_object({}) do |(currency, rate), by_currency|
          validate!(date, currency, rate)
          by_currency[currency] = rate
        end.freeze
      end.freeze
    end

    def rate_for(currency, date)
      return BigDecimal("1") if currency.eur?

      @table.dig(date, currency) || raise(Errors::MissingExchangeRate.new(currency, date))
    end

    # Converts to EUR using the rate of `on`. EUR amounts are returned unchanged.
    def to_eur(money, on:)
      return money if money.currency.eur?

      eur_amount = money.amount.div(rate_for(money.currency, on), DIVISION_DIGITS)
      Money.new(amount: eur_amount, currency: Currency::EUR)
    end

    private

    def validate!(date, currency, rate)
      raise Errors::InvalidExchangeRate, "date must be a Date, got #{date.inspect}" unless date.instance_of?(Date)
      raise Errors::InvalidExchangeRate, "currency must be a Currency, got #{currency.inspect}" unless currency.is_a?(Currency)
      return if rate.is_a?(BigDecimal) && rate.finite? && rate.positive?

      raise Errors::InvalidExchangeRate, "rate for #{currency} on #{date} must be a positive BigDecimal"
    end
  end
end
