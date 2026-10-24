module FreightCli
  # import FILE: imports a MapReduce feed and prints a short JSON summary.
  class ImportCommand
    def initialize(io:)
      @io = io
    end

    def call(args)
      raise UsageError, "usage: import FILE" unless args.size == 1

      result = ImportFeedFile.call(args.first)
      feed_import = result.feed_import
      @io.stdout.puts(
        JSON.pretty_generate(
          "import_id" => feed_import.id, "skipped" => result.skipped, "status" => feed_import.status,
          "stats" => feed_import.stats, "fulfilled_searches" => result.fulfilled_searches
        )
      )
      0
    end
  end
end
