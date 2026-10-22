require "rails_helper"

RSpec.describe Freight::DataIssue do
  it "holds a kind, a sailing code and frozen details" do
    issue = described_class.new(kind: :missing_rate, sailing_code: "ABCD", details: { note: "x" })

    expect(issue.kind).to eq(:missing_rate)
    expect(issue.details).to be_frozen
  end

  it "defaults to no details" do
    expect(described_class.new(kind: :missing_rate, sailing_code: "ABCD").details).to eq({})
  end

  it "rejects unknown kinds" do
    expect { described_class.new(kind: :nope, sailing_code: "ABCD") }.to raise_error(Freight::Errors::InvalidDataIssue)
  end
end
