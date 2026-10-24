require "rails_helper"

RSpec.describe FreightCli::InputParser do
  def parse(text)
    described_class.parse(text)
  end

  it "reads three lines" do
    expect(parse("CNSHA\nNLRTM\ncheapest\n")).to have_attributes(origin: "CNSHA", destination: "NLRTM", criterion: "cheapest")
  end

  it "ignores CRLF, surrounding whitespace, a missing final newline and trailing blank lines" do
    ["CNSHA\r\nNLRTM\r\nfastest\r\n", "  CNSHA \n NLRTM\n fastest  ", "CNSHA\nNLRTM\nfastest\n\n \n\n"].each do |text|
      expect(parse(text)).to have_attributes(origin: "CNSHA", destination: "NLRTM", criterion: "fastest")
    end
  end

  it "ignores a byte order mark" do
    expect(parse("\uFEFFCNSHA\nNLRTM\nfastest").origin).to eq("CNSHA")
  end

  it "rejects missing lines" do
    expect { parse("CNSHA\nNLRTM\n") }.to raise_error(FreightCli::UsageError, /missing input/)
    expect { parse("") }.to raise_error(FreightCli::UsageError, /missing input/)
  end

  it "rejects real extra content" do
    expect { parse("CNSHA\nNLRTM\nfastest\nextra\n") }.to raise_error(FreightCli::UsageError, /extra input/)
  end
end
