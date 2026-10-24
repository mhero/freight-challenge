FactoryBot.define do
  factory :fulfillment_event do
    association :saved_search, factory: :saved_search, status: "fulfilled"
    association :feed_import
    payload { { "legs" => [] } }
  end
end
