require "rails_helper"

# The Dijkstra search must return exactly what the exhaustive search returns,
# including every tie-break, on random schedules full of ties and zero prices.
RSpec.describe Freight::RouteSearch, "against the exhaustive search" do
  let(:ports) { %w[ AAAAA BBBBB CCCCC DDDDD EEEEE FFFFF ] }

  def random_schedule(rng, count)
    Array.new(count) do |index|
      from, to = ports.sample(2, random: rng)
      departs = Date.new(2022, 1, 1) + rng.rand(0..20)
      build_sailing(
        code: format("S%03d", index), from: from, to: to,
        departs: departs.to_s, arrives: (departs + rng.rand(0..8)).to_s, eur: rng.rand(0..30).to_s
      )
    end
  end

  [ Freight::Criteria::CheapestDirect, Freight::Criteria::Cheapest, Freight::Criteria::Fastest ].each do |criterion_class|
    it "agrees for #{criterion_class.new.name} on random schedules" do
      criterion = criterion_class.new
      rng = Random.new(2024)

      12.times do |round|
        sailings = random_schedule(rng, 28)
        fast = described_class.new(sailings)
        exhaustive = BruteForceRouteSearch.new(sailings)

        ports.permutation(2).each do |origin, destination|
          expected = exhaustive.best_route(origin: origin, destination: destination, criterion: criterion)
          actual = fast.best_route(origin: origin, destination: destination, criterion: criterion)

          expect(actual&.sailing_codes).to eq(expected&.sailing_codes), "round #{round}: #{origin} to #{destination}"
        end
      end
    end
  end
end
