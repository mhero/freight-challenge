module FreightCli
  # Client mistakes: reported as JSON on stderr, exit status 2.
  class ClientError < StandardError
    attr_reader :status

    def initialize(message, status:)
      super(message)
      @status = status
    end
  end
end
