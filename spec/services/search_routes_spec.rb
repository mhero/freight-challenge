require "rails_helper"

RSpec.describe SearchRoutes do
  before { ImportFeed.call(sample_feed, source: "spec") }

  def search(origin, destination, criterion)
    described_class.call(origin: origin, destination: destination, criterion: criterion)
  end

  it "answers the three criteria from the database" do
    expect(search("CNSHA", "NLRTM", "cheapest-direct").route.sailing_codes).to eq(%w[ ABCD ])
    expect(search("CNSHA", "NLRTM", "cheapest").route.sailing_codes).to eq(%w[ ERXQ ETRG ])
    expect(search("CNSHA", "NLRTM", "fastest").route.sailing_codes).to eq(%w[ QRST ])
  end

  it "normalizes ports and criterion" do
    expect(search(" cnsha ", "nlrtm", " Fastest ").route.sailing_codes).to eq(%w[ QRST ])
  end

  it "reaches ports through more than one leg and ignores the dead end" do
    expect(search("CNSHA", "BRSSZ", "cheapest").route.sailing_codes).to eq(%w[ ERXQ ETRB ])
    expect(search("ESBCN", "CNSHA", "cheapest").route).to be_nil
  end

  it "returns no route and no warning for known ports without a connection" do
    result = search("NLRTM", "CNSHA", "cheapest")

    expect(result.route).to be_nil
    expect(result.warnings).to be_empty
  end

  it "warns about unknown ports" do
    result = search("CNSHA", "ZZZZZ", "cheapest")

    expect(result.route).to be_nil
    expect(result.warnings).to eq([ "unknown port ZZZZZ" ])
  end

  it "rejects malformed ports and unknown criteria" do
    expect { search("NL", "NLRTM", "cheapest") }.to raise_error(Freight::InvalidPort, /origin/)
    expect { search("CNSHA", "", "cheapest") }.to raise_error(Freight::InvalidPort, /destination/)
    expect { search("CNSHA", "NLRTM", "slowest") }.to raise_error(Freight::UnknownCriterion)
  end
end
