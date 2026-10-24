require "rails_helper"

RSpec.describe Freight::PortCode do
  it "normalizes by trimming and upcasing" do
    expect(described_class.normalize("  cnsha \n")).to eq("CNSHA")
  end

  it "accepts two letters followed by three letters or digits" do
    expect(described_class.valid?("NLRTM")).to be(true)
    expect(described_class.valid?("USNY1")).to be(true)
  end

  it "rejects anything else" do
    %w[ NL RTM123 nlrtm 12RTM N-RTM ].each do |code|
      expect(described_class.valid?(code)).to be(false), "expected #{code} to be invalid"
    end
    expect(described_class.valid?(nil)).to be(false)
  end
end
