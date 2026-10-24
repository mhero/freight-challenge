module Freight
  # UN/LOCODE-style port code: two letters plus three letters or digits.
  module PortCode
    FORMAT = /\A[A-Z]{2}[A-Z0-9]{3}\z/

    def self.normalize(value)
      value.to_s.strip.upcase
    end

    def self.valid?(code)
      FORMAT.match?(code.to_s)
    end
  end
end
