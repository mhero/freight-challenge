module Freight
  # Picks the price of one sailing from the rates the feed offers for it (docs/data_policy.md, P1/P4).
  #
  # - Identical duplicates collapse and are not a conflict.
  # - Conflicting rates: the highest EUR equivalent wins (never under-quote, independent of feed
  #   order). Ties go to the alphabetically lowest currency code. Every discarded rate is reported.
  # - No rate, or a rate that cannot be converted for lack of an exchange rate: the sailing is
  #   left unpriced and the reason is reported.
  class RateResolver
    Resolution = Data.define(:price, :eur_price, :issues) do
      def priced? = !price.nil?
    end

    def initialize(exchange_rates)
      @exchange_rates = exchange_rates
    end

    def resolve(sailing, prices)
      candidates = prices.uniq { |price| [ price.amount.to_s, price.currency.code ] }
      return unpriced(issue(:missing_rate, sailing)) if candidates.empty?

      converted = candidates.map { |price| [ price, @exchange_rates.to_eur(price, on: sailing.departure_date) ] }
      kept, kept_eur = converted.min_by { |price, eur| [ -eur.amount, price.currency.code ] }
      discarded = candidates.reject { |price| price.equal?(kept) }

      Resolution.new(price: kept, eur_price: kept_eur, issues: discarded.map { |price| conflict_issue(sailing, kept, price) })
    rescue Errors::MissingExchangeRate => error
      unpriced(issue(:missing_exchange_rate, sailing, currency: error.currency.code, date: error.date.iso8601))
    end

    private

    def unpriced(issue)
      Resolution.new(price: nil, eur_price: nil, issues: [ issue ])
    end

    def conflict_issue(sailing, kept, discarded)
      issue(:conflicting_rate, sailing, kept: kept.to_s, discarded: discarded.to_s)
    end

    def issue(kind, sailing, details = {})
      DataIssue.new(kind: kind, sailing_code: sailing.code, details: details)
    end
  end
end
