namespace :freight do
  desc "Import the bundled feed (or FEED_PATH) unless it was already imported"
  task seed: :environment do
    result = SeedFeed.call
    if result.nil?
      warn "Seed import disabled (SEED_ON_BOOT=false)"
    elsif result.skipped
      warn "Seed feed already imported (import ##{result.feed_import.id})"
    else
      warn "Seed feed imported (import ##{result.feed_import.id}, #{result.feed_import.stats["sailings"]} sailings)"
    end
  end
end
