module Freight
  # A sailing with its original rate and the EUR price used for comparison.
  Sailing = Data.define(
    :code, :origin_port, :destination_port, :departure_date, :arrival_date, :rate, :price_eur
  ) do
    def duration_days
      (arrival_date - departure_date).to_i
    end
  end
end
