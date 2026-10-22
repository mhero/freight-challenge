require "rails_helper"

RSpec.describe Freight::Sailing do
  it "normalizes ports and exposes the duration in days" do
    sailing = build_sailing(origin: "cnsha", destination: " nlrtm ", departure: "2022-01-29", arrival: "2022-02-15")

    expect(sailing.origin).to eq(Freight::PortCode.new("CNSHA"))
    expect(sailing.destination).to eq(Freight::PortCode.new("NLRTM"))
    expect(sailing.duration_days).to eq(17)
  end

  it "allows arrival on the departure date" do
    expect(build_sailing(departure: "2022-02-01", arrival: "2022-02-01").duration_days).to eq(0)
  end

  it "rejects arrival before departure" do
    expect { build_sailing(departure: "2022-02-02", arrival: "2022-02-01") }
      .to raise_error(Freight::Errors::InvalidSailing, /arrival is before departure/)
  end

  it "rejects a blank code" do
    expect { build_sailing(code: " ") }.to raise_error(Freight::Errors::InvalidSailing, /blank/)
    expect { build_sailing(code: nil) }.to raise_error(Freight::Errors::InvalidSailing, /blank/)
  end

  it "requires Date objects" do
    expect do
      described_class.new(code: "ABCD", origin: "CNSHA", destination: "NLRTM",
                          departure_date: "2022-02-01", arrival_date: Date.iso8601("2022-03-01"))
    end.to raise_error(Freight::Errors::InvalidSailing, /Date/)
  end

  it "rejects malformed ports" do
    expect { build_sailing(origin: "XX") }.to raise_error(Freight::Errors::InvalidPortCode)
  end
end
