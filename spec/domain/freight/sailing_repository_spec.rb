require "rails_helper"

RSpec.describe InMemorySailingRepository do
  let(:sailings) do
    [
      build_sailing(code: "AAAA", from: "CNSHA", to: "ESBCN", departs: "2022-01-01", arrives: "2022-01-10", eur: "10"),
      build_sailing(code: "BBBB", from: "ESBCN", to: "NLRTM", departs: "2022-01-10", arrives: "2022-01-15", eur: "10"),
      build_sailing(code: "LATE", from: "ESBCN", to: "BRSSZ", departs: "2022-01-09", arrives: "2022-01-12", eur: "10"),
      build_sailing(code: "BACK", from: "NLRTM", to: "CNSHA", departs: "2022-01-20", arrives: "2022-01-25", eur: "10"),
      build_sailing(code: "ELSE", from: "DEHAM", to: "NLRTM", departs: "2022-01-01", arrives: "2022-01-02", eur: "10")
    ]
  end

  subject(:repository) { described_class.new(sailings) }

  it "includes the Freight::SailingRepository contract" do
    expect(repository).to be_a(Freight::SailingRepository)
  end

  it "returns the sailings reachable through time-feasible connections, ordered by departure" do
    codes = repository.reachable_from("CNSHA").map(&:code)

    expect(codes).to eq(%w[ AAAA BBBB BACK ])
  end

  it "stops on cycles and returns every sailing once" do
    loop_sailings = [
      build_sailing(code: "ONE1", from: "CNSHA", to: "ESBCN", departs: "2022-01-01", arrives: "2022-01-01", eur: "1"),
      build_sailing(code: "TWO2", from: "ESBCN", to: "CNSHA", departs: "2022-01-01", arrives: "2022-01-01", eur: "1")
    ]

    expect(described_class.new(loop_sailings).reachable_from("CNSHA").map(&:code)).to eq(%w[ ONE1 TWO2 ])
  end

  it "does not connect a sailing that leaves before the previous one arrives" do
    expect(repository.reachable_from("CNSHA").map(&:code)).not_to include("LATE")
  end

  it "returns nothing for a port without departures" do
    expect(repository.reachable_from("BRSSZ")).to eq([])
  end

  it "reports which of the given ports appear in a sailing" do
    expect(repository.known_ports(%w[ CNSHA ZZZZZ BRSSZ ])).to eq(%w[ CNSHA BRSSZ ])
  end
end
