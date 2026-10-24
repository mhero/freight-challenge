require "rails_helper"

RSpec.describe "test environment" do
  it "runs in the test environment against PostgreSQL" do
    expect(Rails.env).to be_test
    expect(ApplicationRecord.connection.adapter_name).to eq("PostgreSQL")
  end
end
