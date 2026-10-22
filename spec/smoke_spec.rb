require "rails_helper"

# Baseline: proves the Docker/Rails/PostgreSQL/RSpec wiring works.
# Replaced by real specs as the domain is built.
RSpec.describe "Environment baseline" do
  it "runs in the test environment" do
    expect(Rails.env).to be_test
  end

  it "talks to PostgreSQL (no SQLite)" do
    expect(ActiveRecord::Base.connection.adapter_name).to eq("PostgreSQL")
    expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
  end

  it "uses the dedicated test database" do
    expect(ActiveRecord::Base.connection.current_database).to eq("freight_challenge_test")
  end

  it "can parse the bundled feed with BigDecimal (no floats for money)" do
    feed = JSON.parse(Rails.root.join("db/feeds/response.json").read, decimal_class: BigDecimal)
    expect(feed.keys).to contain_exactly("sailings", "rates", "exchange_rates")
    expect(feed["exchange_rates"]["2022-01-29"]["usd"]).to be_a(BigDecimal)
  end
end
