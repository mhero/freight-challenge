require "rails_helper"

RSpec.describe Freight::Rate do
  it "pairs a sailing code with a price" do
    rate = build_rate(" ABCD ", "589.30", "USD")

    expect(rate.sailing_code).to eq("ABCD")
    expect(rate.price).to eq(money("589.30", "USD"))
  end

  it "rejects a blank sailing code" do
    expect { described_class.new(sailing_code: "", price: money("1.00", "EUR")) }
      .to raise_error(Freight::Errors::InvalidRate)
  end

  it "rejects a price that is not Money" do
    expect { described_class.new(sailing_code: "ABCD", price: "1.00") }.to raise_error(Freight::Errors::InvalidRate)
  end
end
