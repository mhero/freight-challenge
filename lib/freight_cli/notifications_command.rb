require "optparse"

module FreightCli
  # notifications list | ack: reads the outbox of fulfilled saved searches.
  class NotificationsCommand
    def initialize(io:, inbox: NotificationInbox.new)
      @io = io
      @inbox = inbox
    end

    def call(args)
      action, *rest = args
      case action
      when "list" then list(rest)
      when "ack" then acknowledge(rest)
      else raise UsageError, "usage: notifications list [options] | notifications ack ID... | --through ID"
      end
      0
    end

    private

    def list(args)
      options = {}
      parse(args) do |parser|
        parser.on("--status STATUS") { |value| options[:status] = value }
        parser.on("--limit N", Integer) { |value| options[:limit] = value }
        parser.on("--after-id ID", Integer) { |value| options[:after_id] = value }
        parser.on("--origin PORT") { |value| options[:origin] = value }
        parser.on("--destination PORT") { |value| options[:destination] = value }
        parser.on("--criterion NAME") { |value| options[:criterion] = value }
      end

      page = @inbox.list(**options)
      print_json("notifications" => page.events.map { |event| present(event) }, "next_after_id" => page.next_after_id)
    end

    def acknowledge(args)
      through = nil
      ids = parse(args) { |parser| parser.on("--through ID", Integer) { |value| through = value } }
      raise UsageError, "give either ids or --through ID" if ids.empty? == through.nil?

      count = through ? @inbox.acknowledge_through(through) : @inbox.acknowledge(ids: integers(ids))
      print_json("acknowledged" => count)
    end

    def parse(args)
      parser = OptionParser.new
      yield parser
      parser.parse(args)
    rescue OptionParser::ParseError => e
      raise UsageError, e.message
    end

    def integers(values)
      values.map { |value| Integer(value, 10) }
    rescue ArgumentError
      raise UsageError, "ids must be integers"
    end

    def present(event)
      search = event.saved_search
      {
        "id" => event.id, "origin_port" => search.origin_port, "destination_port" => search.destination_port,
        "criterion" => search.criterion, "fulfilled_by_import_id" => event.feed_import_id,
        "created_at" => event.created_at.iso8601, "acknowledged_at" => event.acknowledged_at&.iso8601,
        "route" => event.payload["legs"]
      }
    end

    def print_json(data)
      @io.stdout.puts(JSON.pretty_generate(data))
    end
  end
end
