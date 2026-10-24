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

  it "includes the Freight::SailingRepository contract" do
    expect(repository).to be_a(Freight::SailingRepository)
  end

  describe "#departures_from" do
    it "returns domain sailings with the original rate and the EUR price of the departure date" do
      priced_sailing("ABCD", amount: "589.30", currency: "USD")

      sailing = repository.departures_from("CNSHA").first

      expect(sailing).to be_a(Freight::Sailing)
      expect(sailing.code).to eq("ABCD")
      expect(sailing.rate).to eq(Freight::Rate.parse("589.30", "USD"))
      expect(sailing.price_eur).to be_within(BigDecimal("0.001")).of(BigDecimal("523.357"))
    end

    it "leaves EUR amounts unconverted" do
      priced_sailing("EFGH", amount: "890.32", currency: "EUR")

      expect(repository.departures_from("CNSHA").first.price_eur).to eq(BigDecimal("890.32"))
    end

    it "excludes sailings that cannot be priced on their departure date" do
      priced_sailing("NOFX", amount: "10.00", currency: "USD", departure: Date.new(2022, 3, 1))
      create(:sailing, sailing_code: "NORT")

      expect(repository.departures_from("CNSHA")).to be_empty
    end

    it "excludes inactive sailings and honours on_or_after" do
      priced_sailing("OLDX", amount: "1.00", currency: "EUR", active: false)
      priced_sailing("KEEP", amount: "1.00", currency: "EUR")

      expect(repository.departures_from("CNSHA").map(&:code)).to eq(%w[ KEEP ])
      expect(repository.departures_from("CNSHA", on_or_after: day + 1)).to be_empty
    end

    it "returns an empty list for a port without departures" do
      expect(repository.departures_from("BRSSZ")).to eq([])
    end
  end

  describe "#known_port?" do
    before { create(:sailing, origin_port: "CNSHA", destination_port: "NLRTM") }

    it "recognizes origin and destination ports of active sailings" do
      expect(repository.known_port?("CNSHA")).to be(true)
      expect(repository.known_port?("NLRTM")).to be(true)
    end

    it "does not know other ports or ports of inactive sailings only" do
      create(:sailing, origin_port: "BRSSZ", destination_port: "DEHAM", active: false)

      expect(repository.known_port?("ZZZZZ")).to be(false)
      expect(repository.known_port?("BRSSZ")).to be(false)
    end
  end
end
