module FreightCli
  # Default command: three lines on stdin, a JSON array of legs on stdout.
  class SearchCommand
    def initialize(io:, service: SearchRoutes.new)
      @io = io
      @service = service
    end

    def call(_args)
      query = InputParser.parse(@io.stdin.read)
      result = @service.call(origin: query.origin, destination: query.destination, criterion: query.criterion)

      result.warnings.each { |warning| @io.stderr.puts(JSON.generate("warning" => warning)) }
      @io.stdout.puts(JSON.pretty_generate(result.route ? result.route.to_legs : []))
      0
    end
  end
end
