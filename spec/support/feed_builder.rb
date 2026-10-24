# Builds small feeds as JSON text for specs, so edge cases use fabricated data.
module FeedBuilder
  def sample_feed
    File.read(Rails.root.join("data/response.json"))
  end

  def feed_json(sailings: [], rates: [], exchange_rates: {})
    JSON.generate("sailings" => sailings, "rates" => rates, "exchange_rates" => exchange_rates)
  end

  def sailing_hash(code, from: "CNSHA", to: "NLRTM", departs: "2022-02-01", arrives: "2022-03-01")
    {
      "origin_port" => from, "destination_port" => to, "departure_date" => departs,
      "arrival_date" => arrives, "sailing_code" => code
    }
  end

  def rate_hash(code, amount, currency)
    { "sailing_code" => code, "rate" => amount, "rate_currency" => currency }
  end

  def usd_on(date, value = 1.126)
    { date => { "usd" => value } }
  end
end

RSpec.configure { |config| config.include FeedBuilder }
