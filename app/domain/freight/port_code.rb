module Freight
  # A UN/LOCODE-style port code. Input is trimmed and upper-cased, then validated.
  class PortCode < Data.define(:code)
    FORMAT = /\A[A-Z]{2}[A-Z0-9]{3}\z/

    def initialize(code:)
      normalized = code.to_s.strip.upcase
      raise Errors::InvalidPortCode, "invalid port code: #{code.inspect}" unless FORMAT.match?(normalized)

      super(code: normalized)
    end

    def to_s = code
  end
end
