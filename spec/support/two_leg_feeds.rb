# Feeds for saved search specs. The first has no way to reach NLRTM, the second adds it.
# Each feed is a full snapshot, so the second repeats the first one's sailing.
module TwoLegFeeds
  def feed_without_second_leg
    feed_json(
      sailings: [ sailing_hash("ERXQ", to: "ESBCN", departs: "2022-01-29", arrives: "2022-02-12") ],
      rates: [ rate_hash("ERXQ", "261.96", "EUR") ]
    )
  end

  def feed_with_second_leg
    feed_json(
      sailings: [
        sailing_hash("ERXQ", to: "ESBCN", departs: "2022-01-29", arrives: "2022-02-12"),
        sailing_hash("ETRG", from: "ESBCN", departs: "2022-02-16", arrives: "2022-02-20")
      ],
      rates: [ rate_hash("ERXQ", "261.96", "EUR"), rate_hash("ETRG", "69.96", "USD") ],
      exchange_rates: usd_on("2022-02-16", 1.1482)
    )
  end
end

RSpec.configure { |config| config.include TwoLegFeeds }
