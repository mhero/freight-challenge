# Reads a feed file from disk and imports it. Shared by the CLI and the startup seed.
class ImportFeedFile
  class FileMissing < Freight::Error; end

  def self.call(path, **options)
    new(path, **options).call
  end

  def initialize(path, reevaluator: ReevaluateSavedSearches)
    @path = path.to_s
    @reevaluator = reevaluator
  end

  def call
    raise FileMissing, "feed file not found: #{@path}" unless File.file?(@path)

    payload = File.read(@path, encoding: "bom|utf-8")
    ImportFeed.call(payload, source: @path, reevaluator: @reevaluator)
  end
end
