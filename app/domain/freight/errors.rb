module Freight
  # All domain errors. Each one maps to a client-facing error code in the CLI (later step).
  module Errors
    class Base < StandardError; end

    class InvalidPortCode < Base; end
    class InvalidCurrency < Base; end
    class InvalidMoney < Base; end
    class InvalidSailing < Base; end
    class InvalidRate < Base; end
    class InvalidRoute < Base; end
    class InvalidExchangeRate < Base; end
    class InvalidDataIssue < Base; end
    class CurrencyMismatch < Base; end
    class UnknownCriterion < Base; end

    # Raised when no EUR-based exchange rate exists for a currency on an exact date.
    # There is deliberately no fallback to nearby dates (see docs/data_policy.md, P4).
    class MissingExchangeRate < Base
      attr_reader :currency, :date

      def initialize(currency, date)
        @currency = currency
        @date = date
        super("no EUR exchange rate for #{currency} on #{date}")
      end
    end
  end
end
