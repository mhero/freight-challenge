module Freight
  # A price offered for a sailing. A sailing may have several (conflicting) rates in the feed.
  class Rate < Data.define(:sailing_code, :price)
    def initialize(sailing_code:, price:)
      code = sailing_code.to_s.strip
      raise Errors::InvalidRate, "sailing code is blank" if code.empty?
      raise Errors::InvalidRate, "#{code}: price must be a Money" unless price.is_a?(Money)

      super(sailing_code: code, price: price)
    end
  end
end
