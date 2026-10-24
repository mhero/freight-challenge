module CliHelper
  CliRun = Struct.new(:exit_code, :stdout, :stderr) do
    def json
      JSON.parse(stdout)
    end

    def error
      JSON.parse(stderr.lines.last).fetch("error")
    end
  end

  def run_cli(*args, stdin: "")
    out = StringIO.new
    err = StringIO.new
    code = FreightCli::Runner.new(argv: args, stdin: StringIO.new(stdin), stdout: out, stderr: err).call
    CliRun.new(code, out.string, err.string)
  end
end

RSpec.configure { |config| config.include CliHelper }
