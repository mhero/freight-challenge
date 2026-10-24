FactoryBot.define do
  factory :sailing do
    sequence(:sailing_code) { |n| format("S%03d", n) }
    origin_port { "CNSHA" }
    destination_port { "NLRTM" }
    departure_date { Date.new(2022, 2, 1) }
    arrival_date { Date.new(2022, 3, 1) }
    active { true }
    association :first_import, factory: :feed_import
    last_seen_import { first_import }
  end
end
