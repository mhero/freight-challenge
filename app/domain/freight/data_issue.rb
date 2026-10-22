module Freight
  # A data-quality finding about a sailing (never dropped silently; persisted by the import in Step 04).
  class DataIssue < Data.define(:kind, :sailing_code, :details)
    KINDS = %i[conflicting_rate missing_rate missing_exchange_rate].freeze

    def initialize(kind:, sailing_code:, details: {})
      raise Errors::InvalidDataIssue, "unknown issue kind: #{kind.inspect}" unless KINDS.include?(kind)

      super(kind: kind, sailing_code: sailing_code, details: details.dup.freeze)
    end
  end
end
