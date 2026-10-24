require "rails_helper"

RSpec.describe Freight::Criteria do
  it "finds a criterion by name" do
    expect(described_class.fetch("cheapest-direct")).to be_a(Freight::Criteria::CheapestDirect)
  end

  it "rejects unknown names and lists the valid ones" do
    expect { described_class.fetch("fastest-ever") }
      .to raise_error(Freight::UnknownCriterion, /expected one of: cheapest-direct/)
  end

  it "has unique names" do
    expect(described_class.names).to eq(described_class.names.uniq)
  end
end
