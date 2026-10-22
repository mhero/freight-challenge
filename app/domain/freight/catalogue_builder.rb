module Freight
  # Combines sailings, rates and exchange rates into a Catalogue.
  class CatalogueBuilder
    def initialize(exchange_rates)
      @resolver = RateResolver.new(exchange_rates)
    end

    def build(sailings:, rates:)
      prices_by_code = rates.group_by(&:sailing_code).transform_values { |group| group.map(&:price) }
      priced_sailings = []
      issues = []

      sailings.each do |sailing|
        resolution = @resolver.resolve(sailing, prices_by_code.fetch(sailing.code, []))
        issues.concat(resolution.issues)
        next unless resolution.priced?

        priced_sailings << PricedSailing.new(sailing: sailing, price: resolution.price, eur_price: resolution.eur_price)
      end

      Catalogue.new(priced_sailings: priced_sailings, issues: issues)
    end
  end
end
