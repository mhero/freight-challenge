FactoryBot.define do
  factory :saved_search do
    origin_port { "CNSHA" }
    destination_port { "NLRTM" }
    criterion { "cheapest" }
    status { "pending" }
  end
end
