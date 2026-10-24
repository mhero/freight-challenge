# Cold start: imports the bundled feed (or the file named by FEED_PATH).
# Idempotent through the feed checksum. Disabled with SEED_ON_BOOT=false.
class SeedFeed
  DEFAULT_PATH = Rails.root.join("data/response.json").to_s

  def self.call(**options)
    new(**options).call
  end

  def initialize(env: ENV, reevaluator: ReevaluateSavedSearches)
    @env = env
    @reevaluator = reevaluator
  end

  # Returns the ImportFeed result, or nil when seeding is disabled.
  def call
    return nil if @env["SEED_ON_BOOT"] == "false"

    ImportFeedFile.call(@env["FEED_PATH"].presence || DEFAULT_PATH, reevaluator: @reevaluator)
  end
end
