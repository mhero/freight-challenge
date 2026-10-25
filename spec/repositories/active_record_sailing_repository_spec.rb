require "rails_helper"

RSpec.describe ActiveRecordSailingRepository do
  subject(:repository) { described_class.new }

  let(:day) { Date.new(2022, 2, 1) }

  before { create(:exchange_rate, date: day, currency: "usd", rate: BigDecimal("1.126")) }

  def priced_sailing(code, amount:, currency:, departure: day, **attributes)
    sailing = create(:sailing, sailing_code: code, departure_date: departure, **attributes)
    create(:rate, sailing: sailing, amount: amount, currency: currency)
    sailing
  end

  def hop(code, from, to, departs, arrives, **options)
    priced_sailing(code, amount: "1.00", currency: "EUR", origin_port: from, destination_port: to,
                         departure: Date.parse(departs), arrival_date: Date.parse(arrives), **options)
  end

  it "includes the Freight::SailingRepository contract" do
    expect(repository).to be_a(Freight::SailingRepository)
  end

  describe "#reachable_from" do
    it "returns domain sailings with the original rate and the EUR price of the departure date" do
      priced_sailing("ABCD", amount: "589.30", currency: "USD")

      sailing = repository.reachable_from("CNSHA").first

      expect(sailing).to be_a(Freight::Sailing)
      expect(sailing.code).to eq("ABCD")
      expect(sailing.departure_date).to eq(day)
      expect(sailing.rate).to eq(Freight::Rate.parse("589.30", "USD"))
      expect(sailing.price_eur).to be_within(BigDecimal("0.001")).of(BigDecimal("523.357"))
    end

    it "leaves EUR amounts unconverted" do
      priced_sailing("EFGH", amount: "890.32", currency: "EUR")

      expect(repository.reachable_from("CNSHA").first.price_eur).to eq(BigDecimal("890.32"))
    end

    it "excludes sailings that cannot be priced on their departure date" do
      priced_sailing("NOFX", amount: "10.00", currency: "USD", departure: Date.new(2022, 3, 1))
      create(:sailing, sailing_code: "NORT")

      expect(repository.reachable_from("CNSHA")).to be_empty
    end

    it "excludes inactive sailings" do
      priced_sailing("OLDX", amount: "1.00", currency: "EUR", active: false)
      priced_sailing("KEEP", amount: "1.00", currency: "EUR")

      expect(repository.reachable_from("CNSHA").map(&:code)).to eq(%w[ KEEP ])
    end

    it "follows time-feasible connections over several hops and leaves out the rest" do
      hop("HOP1", "CNSHA", "ESBCN", "2022-02-01", "2022-02-05")
      hop("HOP2", "ESBCN", "BRSSZ", "2022-02-05", "2022-02-09")
      hop("HOP3", "BRSSZ", "NLRTM", "2022-02-10", "2022-02-12")
      hop("EARL", "ESBCN", "NLRTM", "2022-02-04", "2022-02-06")
      hop("ELSE", "DEHAM", "NLRTM", "2022-02-01", "2022-02-02")

      expect(repository.reachable_from("CNSHA").map(&:code)).to eq(%w[ HOP1 HOP2 HOP3 ])
    end

    it "does not connect through a sailing that cannot be priced" do
      hop("HOP1", "CNSHA", "ESBCN", "2022-02-01", "2022-02-05")
      priced_sailing("GAPX", amount: "5.00", currency: "USD", departure: Date.new(2022, 2, 5),
                             origin_port: "ESBCN", destination_port: "BRSSZ", arrival_date: Date.new(2022, 2, 9))
      hop("HOP3", "BRSSZ", "NLRTM", "2022-02-10", "2022-02-12")

      expect(repository.reachable_from("CNSHA").map(&:code)).to eq(%w[ HOP1 ])
    end

    it "terminates on cycles and returns each sailing once" do
      hop("OUTB", "CNSHA", "ESBCN", "2022-02-01", "2022-02-01")
      hop("BACK", "ESBCN", "CNSHA", "2022-02-01", "2022-02-01")

      expect(repository.reachable_from("CNSHA").map(&:code)).to eq(%w[ BACK OUTB ])
    end

    it "returns an empty list for a port without departures" do
      expect(repository.reachable_from("BRSSZ")).to eq([])
    end

    it "sets the statement timeout for the load" do
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| statements << payload[:sql] }

      described_class.new(statement_timeout_ms: 1234).reachable_from("CNSHA")

      expect(statements).to include("SET LOCAL statement_timeout = 1234")
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    it "reads the timeout from SEARCH_STATEMENT_TIMEOUT_MS" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("SEARCH_STATEMENT_TIMEOUT_MS", anything).and_return("4500")

      expect(described_class.default_timeout_ms).to eq(4500)
    end

    it "turns a cancelled statement into an explicit resource-limit error" do
      allow(Sailing).to receive(:reachable_priced).and_raise(ActiveRecord::QueryCanceled, "canceling statement due to statement timeout")

      expect { repository.reachable_from("CNSHA") }.to raise_error(Freight::SearchTimeout, /time limit/)
    end
  end

  describe "#known_ports" do
    before { create(:sailing, origin_port: "CNSHA", destination_port: "NLRTM") }

    it "recognizes origin and destination ports of active sailings, both in one call" do
      expect(repository.known_ports(%w[ CNSHA NLRTM ])).to contain_exactly("CNSHA", "NLRTM")
    end

    it "does not know other ports or ports of inactive sailings only" do
      create(:sailing, origin_port: "BRSSZ", destination_port: "DEHAM", active: false)

      expect(repository.known_ports(%w[ ZZZZZ BRSSZ ])).to eq([])
    end
  end
end
