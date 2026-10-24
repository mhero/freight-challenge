require "rails_helper"

RSpec.describe Freight::Sailing do
  it "knows its duration in days" do
    sailing = described_class.new(
      code: "QRST", origin_port: "CNSHA", destination_port: "NLRTM",
      departure_date: Date.new(2022, 1, 29), arrival_date: Date.new(2022, 2, 15),
      rate: Freight::Rate.parse("761.96", "EUR"), price_eur: BigDecimal("761.96")
    )

    expect(sailing.duration_days).to eq(17)
  end
end
