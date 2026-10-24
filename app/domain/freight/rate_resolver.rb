module Freight
  # Picks the effective rate of one sailing from the candidates in a feed.
  # Several different rates: the highest in EUR wins (independent of feed order).
  # A candidate that cannot be converted leaves the sailing unpriced.
  class RateResolver
    Resolution = Data.define(:rate, :price_eur, :discarded, :conflict, :unpriced_reason) do
      def priced?
        !rate.nil?
      end
    end

    def initialize(exchange_rates)
      @exchange_rates = exchange_rates
    end

    def resolve(departure_date:, candidates:)
      rates = distinct(candidates)
      return resolution(unpriced_reason: "no rate in feed") if rates.empty?

      priced = rates.map { |rate| [ rate, @exchange_rates.to_eur(rate, on: departure_date) ] }
      unconvertible = priced.select { |_, eur| eur.nil? }.map { |rate, _| rate.currency }
      if unconvertible.any?
        reason = "no exchange rate for #{unconvertible.uniq.join(", ")} on #{departure_date}"
        return resolution(discarded: rates, conflict: rates.size > 1, unpriced_reason: reason)
      end

      chosen, eur = priced.max_by { |rate, price| [ price, rate.amount_text, rate.currency ] }
      resolution(rate: chosen, price_eur: eur, discarded: rates - [ chosen ], conflict: rates.size > 1)
    end

    private

    # Identical rates collapse; equal values written differently ("1.0", "1.00") count as one.
    def distinct(candidates)
      candidates
        .sort_by { |rate| [ rate.amount_text, rate.currency ] }
        .uniq { |rate| [ rate.amount.to_s("F"), rate.currency ] }
    end

    def resolution(**attributes)
      defaults = { rate: nil, price_eur: nil, discarded: [], conflict: false, unpriced_reason: nil }
      Resolution.new(**defaults, **attributes)
    end
  end
end
