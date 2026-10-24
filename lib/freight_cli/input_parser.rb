module FreightCli
  # Reads the three input lines: origin port, destination port, criterion.
  # Line endings, surrounding whitespace and trailing blank lines are ignored.
  class InputParser
    Query = Data.define(:origin, :destination, :criterion)

    LINE_COUNT = 3

    def self.parse(text)
      lines = text.to_s.scrub.delete_prefix("\uFEFF").lines.map(&:strip)
      lines.pop while lines.last&.empty?

      if lines.size < LINE_COUNT
        raise UsageError, "missing input: expected origin port, destination port and criterion, one per line"
      end
      raise UsageError, "unexpected extra input after the criterion (expected exactly #{LINE_COUNT} lines)" if lines.size > LINE_COUNT

      Query.new(origin: lines[0], destination: lines[1], criterion: lines[2])
    end
  end
end
