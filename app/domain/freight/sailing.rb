module Freight
  # A sailing with its original rate and the EUR price used for comparison.
  Sailing = Data.define(
    :code, :origin_port, :destination_port, :departure_date, :arrival_date, :rate, :price_eur
  ) do
    def duration_days
      (arrival_date - departure_date).to_i
    end

    # One leg in the output format of the challenge. The rate is printed as received.
    def to_leg
      {
        "origin_port" => origin_port, "destination_port" => destination_port,
        "departure_date" => departure_date.iso8601, "arrival_date" => arrival_date.iso8601,
        "sailing_code" => code, "rate" => rate.amount_text, "rate_currency" => rate.currency
      }
    end
  end
end
