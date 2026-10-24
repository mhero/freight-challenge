FactoryBot.define do
  factory :feed_import do
    source { "spec" }
    sequence(:checksum) { |n| Digest::SHA256.hexdigest("feed-#{n}") }
    status { "completed" }
    raw_payload { "{}" }
    started_at { Time.current }
    finished_at { Time.current }
  end
end
