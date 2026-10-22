module Freight
  # An ISO 4217-style currency code and its number of minor-unit digits.
  class Currency < Data.define(:code)
    FORMAT = /\A[A-Z]{3}\z/
    DEFAULT_EXPONENT = 2
    EXPONENTS = { "JPY" => 0 }.freeze

    def initialize(code:)
      normalized = code.to_s.strip.upcase
      raise Errors::InvalidCurrency, "invalid currency code: #{code.inspect}" unless FORMAT.match?(normalized)

      super(code: normalized)
    end

    def exponent = EXPONENTS.fetch(code, DEFAULT_EXPONENT)

    def eur? = code == "EUR"

    def to_s = code

    EUR = new("EUR")
  end
end
