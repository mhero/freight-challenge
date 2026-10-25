require "rails_helper"

RSpec.describe Freight::RouteSearch do
  let(:criterion) { LowestTotalCriterion.new }
  let(:search) { described_class.new(sailings) }

  def sailing(code, from, to, departs, arrives, eur)
    build_sailing(code: code, from: from, to: to, departs: departs, arrives: arrives, eur: eur)
  end

  def best(origin = "CNSHA", destination = "NLRTM", with: criterion)
    search.best_route(origin: origin, destination: destination, criterion: with)
  end

  context "with a direct and an indirect option" do
    let(:sailings) do
      [
        sailing("DIRC", "CNSHA", "NLRTM", "2022-02-01", "2022-03-01", "500"),
        sailing("ERXQ", "CNSHA", "ESBCN", "2022-01-29", "2022-02-12", "261.96"),
        sailing("ETRG", "ESBCN", "NLRTM", "2022-02-16", "2022-02-20", "60.93")
      ]
    end

    it "returns every leg of the cheapest route" do
      expect(best.sailing_codes).to eq(%w[ ERXQ ETRG ])
      expect(best.total_eur).to eq(BigDecimal("322.89"))
    end

    it "honours the leg limit of the criterion" do
      route = best(with: Freight::Criteria::CheapestDirect.new)

      expect(route.sailing_codes).to eq(%w[ DIRC ])
    end
  end

  it "returns nil when there is no sailing between the ports" do
    sailings = [ sailing("ABCD", "CNSHA", "ESBCN", "2022-01-29", "2022-02-12", "10") ]

    expect(described_class.new(sailings).best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)).to be_nil
  end

  context "with more than two legs" do
    let(:sailings) do
      [
        sailing("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-10", "10"),
        sailing("BBBB", "ESBCN", "BRSSZ", "2022-01-11", "2022-01-20", "10"),
        sailing("CCCC", "BRSSZ", "NLRTM", "2022-01-21", "2022-01-30", "10")
      ]
    end

    it "chains as many legs as needed" do
      expect(best.sailing_codes).to eq(%w[ AAAA BBBB CCCC ])
    end
  end

  context "when the second leg departs before the first one arrives" do
    let(:sailings) do
      [
        sailing("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-10", "10"),
        sailing("BBBB", "ESBCN", "NLRTM", "2022-01-09", "2022-01-15", "10")
      ]
    end

    it "does not connect them" do
      expect(best).to be_nil
    end
  end

  context "when the second leg departs on the arrival day" do
    let(:sailings) do
      [
        sailing("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-10", "10"),
        sailing("BBBB", "ESBCN", "NLRTM", "2022-01-10", "2022-01-15", "10")
      ]
    end

    it "allows the same-day connection" do
      expect(best.sailing_codes).to eq(%w[ AAAA BBBB ])
    end
  end

  context "with a dead end" do
    let(:sailings) do
      [
        sailing("ETRB", "ESBCN", "BRSSZ", "2022-02-16", "2022-03-14", "5"),
        sailing("ERXQ", "CNSHA", "ESBCN", "2022-01-29", "2022-02-12", "20"),
        sailing("ETRG", "ESBCN", "NLRTM", "2022-02-16", "2022-02-20", "20")
      ]
    end

    it "ignores the branch that leads nowhere" do
      expect(best.sailing_codes).to eq(%w[ ERXQ ETRG ])
    end

    it "returns nil when only dead ends are reachable" do
      expect(best("CNSHA", "DEHAM")).to be_nil
    end
  end

  context "with cycles in the schedule" do
    let(:sailings) do
      [
        sailing("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-02", "10"),
        sailing("BACK", "ESBCN", "CNSHA", "2022-01-03", "2022-01-04", "1"),
        sailing("BCYC", "ESBCN", "BRSSZ", "2022-01-03", "2022-01-04", "10"),
        sailing("CYCL", "BRSSZ", "ESBCN", "2022-01-05", "2022-01-06", "1"),
        sailing("CDST", "BRSSZ", "NLRTM", "2022-01-05", "2022-01-06", "10")
      ]
    end

    it "never visits a port twice" do
      route = best

      ports = route.legs.map(&:origin_port) + [ route.destination_port ]
      expect(ports).to eq(ports.uniq)
      expect(route.sailing_codes).to eq(%w[ AAAA BCYC CDST ])
    end

    it "terminates when the destination is unreachable" do
      expect(best("CNSHA", "DEHAM")).to be_nil
    end
  end

  it "queues only the best route to each sailing" do
    sailings = [
      sailing("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-02", "10"),
      sailing("AAAB", "CNSHA", "ESBCN", "2022-01-01", "2022-01-03", "20"),
      sailing("BBBB", "ESBCN", "NLRTM", "2022-01-05", "2022-01-06", "10")
    ]
    queue = Freight::MinHeap.new
    allow(Freight::MinHeap).to receive(:new).and_return(queue)
    pushed = []
    allow(queue).to receive(:push).and_wrap_original { |original, key, route| pushed << route.sailing_codes; original.call(key, route) }

    described_class.new(sailings).best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

    expect(pushed.count(%w[ AAAB BBBB ])).to eq(0)
  end

  it "finds nothing when origin and destination are the same port" do
    sailings = [ sailing("AAAA", "CNSHA", "NLRTM", "2022-01-01", "2022-01-02", "10") ]

    expect(described_class.new(sailings).best_route(origin: "CNSHA", destination: "CNSHA", criterion: criterion)).to be_nil
  end

  it "prefers a costlier but earlier arrival when only it connects in time" do
    sailings = [
      sailing("CHEP", "CNSHA", "ESBCN", "2022-01-01", "2022-01-20", "10"),
      sailing("FAST", "CNSHA", "ESBCN", "2022-01-01", "2022-01-05", "20"),
      sailing("ONWD", "ESBCN", "NLRTM", "2022-01-10", "2022-01-12", "10")
    ]

    route = described_class.new(sailings).best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

    expect(route.sailing_codes).to eq(%w[ FAST ONWD ])
  end

  it "ignores sailings that cannot be reached from the origin" do
    sailings = [
      sailing("AAAA", "CNSHA", "ESBCN", "2022-01-01", "2022-01-02", "10"),
      sailing("ZZZZ", "BRSSZ", "NLRTM", "2022-01-03", "2022-01-04", "1")
    ]

    route = described_class.new(sailings).best_route(origin: "CNSHA", destination: "NLRTM", criterion: criterion)

    expect(route).to be_nil
  end
end
