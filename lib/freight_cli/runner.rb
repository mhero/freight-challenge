require "json"

module FreightCli
  # Thin interface: picks the command, maps errors to the exit status contract.
  #   0 success, 2 client error (JSON on stderr), 1 internal error or resource limit (JSON on stderr)
  class Runner
    Streams = Data.define(:stdin, :stdout, :stderr)

    USAGE = <<~TEXT.freeze
      Usage:
        bin/freight < input.txt     origin port, destination port, criterion (one per line)
        bin/freight import FILE     import a MapReduce feed
        bin/freight notifications list [--status unacknowledged|acknowledged|all] [--limit N]
                                       [--after-id ID] [--origin P] [--destination P] [--criterion C]
        bin/freight notifications ack ID [ID...] | --through ID
      Criteria: cheapest-direct, cheapest, fastest
    TEXT

    def initialize(argv:, stdin:, stdout:, stderr:)
      @argv = argv
      @io = Streams.new(stdin: stdin, stdout: stdout, stderr: stderr)
    end

    def call
      command, *args = @argv
      return help if %w[ help -h --help ].include?(command)

      build_command(command).call(args)
    rescue ClientError => e
      fail_with(e.status, e.message, exit_code: 2)
    rescue Freight::InvalidPort, Freight::UnknownCriterion, InvalidFeed, NotificationInbox::InvalidQuery => e
      fail_with(422, e.message, exit_code: 2)
    rescue ImportFeedFile::FileMissing => e
      fail_with(404, e.message, exit_code: 2)
    rescue Freight::SearchTimeout => e
      fail_with(503, e.message, exit_code: 1)
    rescue StandardError => e
      fail_with(500, "internal error: #{e.class}: #{e.message}", exit_code: 1)
    end

    private

    def build_command(name)
      case name
      when nil, "search" then SearchCommand.new(io: @io)
      when "import" then ImportCommand.new(io: @io)
      when "notifications" then NotificationsCommand.new(io: @io)
      else raise UsageError, "unknown command #{name.inspect}, try --help"
      end
    end

    def help
      @io.stdout.puts(USAGE)
      0
    end

    def fail_with(status, message, exit_code:)
      @io.stderr.puts(JSON.generate("error" => { "code" => status, "message" => message }))
      exit_code
    end
  end
end
