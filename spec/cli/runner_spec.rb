require "rails_helper"

RSpec.describe FreightCli::Runner do
  before { ImportFeed.call(sample_feed, source: "spec") }

  def pretty(legs)
    "#{JSON.pretty_generate(legs)}\n"
  end

  describe "the three README scenarios on the sample data" do
    it "cheapest-direct prints ABCD" do
      run = run_cli(stdin: "CNSHA\nNLRTM\ncheapest-direct\n")

      expect(run.exit_code).to eq(0)
      expect(run.stderr).to be_empty
      expect(run.stdout).to eq(
        pretty(
          [ { "origin_port" => "CNSHA", "destination_port" => "NLRTM", "departure_date" => "2022-02-01",
              "arrival_date" => "2022-03-01", "sailing_code" => "ABCD", "rate" => "589.30", "rate_currency" => "USD" } ]
        )
      )
    end

    it "cheapest prints every leg of ERXQ + ETRG" do
      run = run_cli(stdin: "CNSHA\nNLRTM\ncheapest\n")

      expect(run.exit_code).to eq(0)
      expect(run.json).to eq(
        [
          { "origin_port" => "CNSHA", "destination_port" => "ESBCN", "departure_date" => "2022-01-29",
            "arrival_date" => "2022-02-12", "sailing_code" => "ERXQ", "rate" => "261.96", "rate_currency" => "EUR" },
          { "origin_port" => "ESBCN", "destination_port" => "NLRTM", "departure_date" => "2022-02-16",
            "arrival_date" => "2022-02-20", "sailing_code" => "ETRG", "rate" => "69.96", "rate_currency" => "USD" }
        ]
      )
    end

    it "fastest prints QRST" do
      run = run_cli(stdin: "CNSHA\nNLRTM\nfastest\n")

      expect(run.json.map { |leg| leg["sailing_code"] }).to eq(%w[ QRST ])
      expect(run.json.first).to include("departure_date" => "2022-01-29", "arrival_date" => "2022-02-15", "rate" => "761.96")
    end
  end

  it "prints JPY rates exactly as received" do
    ImportFeed.call(
      feed_json(sailings: [ sailing_hash("JPYX", from: "JPTYO", to: "NLRTM", departs: "2022-01-31") ],
                rates: [ rate_hash("JPYX", "97453.00", "JPY") ], exchange_rates: { "2022-01-31" => { "jpy" => 131.2 } }),
      source: "jpy"
    )

    expect(run_cli(stdin: "JPTYO\nNLRTM\ncheapest\n").json.first).to include("rate" => "97453.00", "rate_currency" => "JPY")
  end

  it "accepts CRLF, whitespace, lowercase and trailing blank lines" do
    run = run_cli(stdin: "  cnsha \r\nnlrtm\r\nFASTEST\r\n\r\n\r\n")

    expect(run.exit_code).to eq(0)
    expect(run.json.first["sailing_code"]).to eq("QRST")
  end

  it "prints [] with exit 0 when there is no route" do
    run = run_cli(stdin: "NLRTM\nCNSHA\ncheapest\n")

    expect(run.exit_code).to eq(0)
    expect(run.stdout).to eq("[]\n")
    expect(run.stderr).to be_empty
  end

  it "prints [] and a warning on stderr for an unknown port" do
    run = run_cli(stdin: "CNSHA\nZZZZZ\ncheapest\n")

    expect(run.exit_code).to eq(0)
    expect(run.stdout).to eq("[]\n")
    expect(JSON.parse(run.stderr)).to eq("warning" => "unknown port ZZZZZ")
  end

  describe "client errors (exit 2, JSON on stderr, nothing on stdout)" do
    {
      "a malformed port" => [ "NL\nNLRTM\ncheapest\n", 422, /origin port/ ],
      "an invalid criterion" => [ "CNSHA\nNLRTM\nslowest\n", 422, /unknown criterion/ ],
      "missing lines" => [ "CNSHA\nNLRTM\n", 400, /missing input/ ],
      "extra lines" => [ "CNSHA\nNLRTM\ncheapest\nmore\n", 400, /extra input/ ]
    }.each do |name, (stdin, status, message)|
      it "reports #{name}" do
        run = run_cli(stdin: stdin)

        expect(run.exit_code).to eq(2)
        expect(run.stdout).to be_empty
        expect(run.error).to include("code" => status)
        expect(run.error["message"]).to match(message)
      end
    end

    it "reports an unknown command" do
      run = run_cli("explode")

      expect(run.exit_code).to eq(2)
      expect(run.error).to include("code" => 400)
    end
  end

  it "reports internal errors with exit 1" do
    failing = instance_double(SearchRoutes)
    allow(failing).to receive(:call).and_raise("boom")
    allow(SearchRoutes).to receive(:new).and_return(failing)

    run = run_cli(stdin: "CNSHA\nNLRTM\ncheapest\n")

    expect(run.exit_code).to eq(1)
    expect(run.stdout).to be_empty
    expect(run.error).to include("code" => 500)
    expect(run.error["message"]).to include("boom")
  end

  it "prints usage on --help" do
    run = run_cli("--help")

    expect(run.exit_code).to eq(0)
    expect(run.stdout).to include("cheapest-direct")
  end

  describe "import" do
    let(:directory) { Pathname(Dir.mktmpdir) }

    after { FileUtils.remove_entry(directory) }

    it "imports a feed file and reports a summary, skipping it the second time" do
      path = directory.join("feed.json")
      path.write(feed_json(sailings: [ sailing_hash("NEWX") ], rates: [ rate_hash("NEWX", "1.00", "EUR") ]))

      first = run_cli("import", path.to_s)
      second = run_cli("import", path.to_s)

      expect(first.exit_code).to eq(0)
      expect(first.json).to include("skipped" => false, "status" => "completed")
      expect(second.json).to include("skipped" => true)
    end

    it "reports a missing file, an invalid feed and wrong usage" do
      path = directory.join("bad.json")
      path.write("not json")

      expect(run_cli("import", directory.join("nope.json").to_s).error).to include("code" => 404)
      expect(run_cli("import", path.to_s).error).to include("code" => 422)
      expect(run_cli("import").error).to include("code" => 400)
      expect(run_cli("import").exit_code).to eq(2)
    end
  end
end
