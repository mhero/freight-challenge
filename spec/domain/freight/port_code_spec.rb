require "rails_helper"

RSpec.describe Freight::PortCode do
  it "trims and upper-cases the code" do
    expect(described_class.new("  cnsha ").code).to eq("CNSHA")
  end

  it "accepts digits in the location part" do
    expect(described_class.new("USNY1").code).to eq("USNY1")
  end

  it "accepts another PortCode" do
    expect(described_class.new(described_class.new("nlrtm"))).to eq(described_class.new("NLRTM"))
  end

  it "is a value object usable as a hash key" do
    expect({ described_class.new("CNSHA") => 1 }[described_class.new("cnsha")]).to eq(1)
  end

  it "prints as its code" do
    expect(described_class.new("esbcn").to_s).to eq("ESBCN")
  end

  [ "", nil, "CNSH", "CNSHAA", "1NSHA", "CN-HA", "CN SHA" ].each do |bad|
    it "rejects #{bad.inspect}" do
      expect { described_class.new(bad) }.to raise_error(Freight::Errors::InvalidPortCode)
    end
  end
end
