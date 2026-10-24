require "rails_helper"

RSpec.describe Freight::SailingConsolidator do
  def record(code, arrival: Date.new(2022, 3, 1))
    Freight::SailingRecord.new(
      code: code, origin_port: "CNSHA", destination_port: "NLRTM",
      departure_date: Date.new(2022, 2, 1), arrival_date: arrival
    )
  end

  it "keeps distinct sailings" do
    result = described_class.call([ record("AAAA"), record("BBBB") ])

    expect(result.sailings.map(&:code)).to eq(%w[ AAAA BBBB ])
    expect(result.conflicts).to be_empty
  end

  it "collapses identical duplicates" do
    result = described_class.call([ record("AAAA"), record("AAAA") ])

    expect(result.sailings.size).to eq(1)
    expect(result.conflicts).to be_empty
  end

  it "excludes a code whose records disagree and reports both variants" do
    result = described_class.call([ record("AAAA"), record("AAAA", arrival: Date.new(2022, 3, 5)), record("BBBB") ])

    expect(result.sailings.map(&:code)).to eq(%w[ BBBB ])
    expect(result.conflicts.keys).to eq(%w[ AAAA ])
    expect(result.conflicts["AAAA"].size).to eq(2)
  end
end
