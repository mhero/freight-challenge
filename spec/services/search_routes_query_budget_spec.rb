require "rails_helper"

# A search costs a constant number of queries: one recursive CTE for the sailings and one for the
# exchange rates, whatever the number of legs or ports on the way.
RSpec.describe SearchRoutes, "query budget" do
  # A chain of single-sailing hops over ports AAAAA, BBBBB, CCCCC...
  def chain_feed(hops)
    ports = ("A".."H").first(hops + 1).map { |letter| letter * 5 }
    start = Date.new(2022, 3, 1)
    sailings = Array.new(hops) do |index|
      sailing_hash(format("HOP%02d", index), from: ports[index], to: ports[index + 1],
                   departs: (start + (2 * index)).to_s, arrives: (start + (2 * index) + 1).to_s)
    end
    rates = sailings.map { |sailing| rate_hash(sailing["sailing_code"], "10.00", "USD") }
    exchange_rates = sailings.to_h { |sailing| [ sailing["departure_date"], { "usd" => 1.1 } ] }
    feed_json(sailings: sailings, rates: rates, exchange_rates: exchange_rates)
  end

  def search(origin, destination, criterion = "cheapest")
    described_class.call(origin: origin, destination: destination, criterion: criterion)
  end

  it "runs at most two queries for a chain of seven hops, and the same number for a shorter chain" do
    ImportFeed.call(chain_feed(7), source: "seven hops")
    long_queries = queries_run { expect(search("AAAAA", "HHHHH").route.sailing_codes.size).to eq(7) }

    ImportFeed.call(chain_feed(3), source: "three hops")
    short_queries = queries_run { expect(search("AAAAA", "DDDDD").route.sailing_codes.size).to eq(3) }

    expect(long_queries.size).to be <= 2
    expect(long_queries.size).to eq(short_queries.size)
    expect(long_queries.first).to include("WITH RECURSIVE")
  end

  it "stays within the budget for every criterion" do
    ImportFeed.call(chain_feed(7), source: "seven hops")

    # cheapest-direct needs a single sailing, so it asks for the first hop; the others for the whole chain.
    { "cheapest-direct" => "BBBBB", "cheapest" => "HHHHH", "fastest" => "HHHHH" }.each do |criterion, destination|
      queries = queries_run { expect(search("AAAAA", destination, criterion).route).to be_present }

      expect(queries.size).to be <= 2
    end
  end

  it "checks both ports in one extra query, and only when the search is unfulfilled" do
    ImportFeed.call(chain_feed(3), source: "three hops")

    found = queries_run { search("AAAAA", "DDDDD") }
    missing = queries_run { search("AAAAA", "ZZZZZ") }

    expect(found.grep(/unnest/)).to be_empty
    expect(missing.grep(/unnest/).size).to eq(1)
  end
end
