FactoryBot.define do
  factory :rate do
    sailing
    import { sailing.last_seen_import }
    amount { "100.00" }
    currency { "EUR" }
  end
end
