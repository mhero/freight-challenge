FactoryBot.define do
  factory :exchange_rate do
    date { Date.new(2022, 2, 1) }
    currency { "usd" }
    rate { BigDecimal("1.126") }
    association :import, factory: :feed_import
  end
end
