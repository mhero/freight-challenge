module FreightCli
  class UsageError < ClientError
    def initialize(message)
      super(message, status: 400)
    end
  end
end
