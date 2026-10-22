module Freight
  # One sailing leg between two ports. Dates only (the feed has no times).
  class Sailing < Data.define(:code, :origin, :destination, :departure_date, :arrival_date)
    def initialize(code:, origin:, destination:, departure_date:, arrival_date:)
      code = code.to_s.strip
      raise Errors::InvalidSailing, "sailing code is blank" if code.empty?
      unless [ departure_date, arrival_date ].all? { |date| date.instance_of?(Date) }
        raise Errors::InvalidSailing, "#{code}: dates must be Date objects"
      end
      raise Errors::InvalidSailing, "#{code}: arrival is before departure" if arrival_date < departure_date

      super(
        code: code,
        origin: PortCode.new(origin),
        destination: PortCode.new(destination),
        departure_date: departure_date,
        arrival_date: arrival_date
      )
    end

    def duration_days = (arrival_date - departure_date).to_i
  end
end
