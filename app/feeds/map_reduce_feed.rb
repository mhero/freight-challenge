require "json"

# Adapter for the MapReduce JSON feed. It knows the file format and nothing else:
# it validates the structure and every record and returns domain objects.
# Bad records are returned as rejections, never dropped silently.
class MapReduceFeed
  Rejection = Data.define(:section, :reference, :reason, :raw)
  RateRecord = Data.define(:sailing_code, :rate)
  ExchangeRateRecord = Data.define(:date, :currency, :rate)
  Parsed = Data.define(:sailings, :rates, :exchange_rates, :rejections)

  class RecordError < StandardError; end

  CODE_FORMAT = /\A[A-Za-z0-9_-]{1,32}\z/
  CURRENCY_FORMAT = /\A[a-z]{3}\z/
  EXCHANGE_RATE_SCALE = 8
  EXCHANGE_RATE_LIMIT = BigDecimal(10)**10

  def self.parse(text)
    new(text).parse
  end

  def initialize(text)
    @text = text.to_s.dup.force_encoding(Encoding::UTF_8)
    @rejections = []
  end

  def parse
    document = load_document
    sailings = records(document, "sailings") { |raw| sailing_record(raw) }
    rates = records(document, "rates") { |raw| rate_record(raw) }
    exchange_rates = exchange_rate_records(document["exchange_rates"])
    Parsed.new(sailings: sailings, rates: rates, exchange_rates: exchange_rates, rejections: @rejections)
  end

  private

  def load_document
    raise InvalidFeed, "payload is not valid UTF-8" unless @text.valid_encoding?

    document = JSON.parse(@text, decimal_class: BigDecimal)
    raise InvalidFeed, "feed must be a JSON object" unless document.is_a?(Hash)
    raise InvalidFeed, "\"sailings\" must be an array" unless document["sailings"].is_a?(Array)
    raise InvalidFeed, "\"rates\" must be an array" unless document["rates"].is_a?(Array)
    raise InvalidFeed, "\"exchange_rates\" must be an object" unless document["exchange_rates"].is_a?(Hash)

    document
  rescue JSON::ParserError => e
    raise InvalidFeed, "invalid JSON: #{e.message.truncate(120)}"
  end

  def records(document, section)
    document.fetch(section).filter_map do |raw|
      reject_on_error(section, reference_of(raw), raw) { yield raw }
    end
  end

  def reject_on_error(section, reference, raw)
    yield
  rescue RecordError, Freight::InvalidRate => e
    @rejections << Rejection.new(section: section, reference: reference, reason: e.message, raw: raw)
    nil
  end

  def reference_of(raw)
    raw["sailing_code"].to_s if raw.is_a?(Hash)
  end

  def sailing_record(raw)
    raise RecordError, "record must be an object" unless raw.is_a?(Hash)

    departure = date_field(raw["departure_date"], "departure_date")
    arrival = date_field(raw["arrival_date"], "arrival_date")
    raise RecordError, "arrival_date is before departure_date" if arrival < departure

    Freight::SailingRecord.new(
      code: code_field(raw), origin_port: port_field(raw["origin_port"], "origin_port"),
      destination_port: port_field(raw["destination_port"], "destination_port"),
      departure_date: departure, arrival_date: arrival
    )
  end

  def rate_record(raw)
    raise RecordError, "record must be an object" unless raw.is_a?(Hash)

    RateRecord.new(sailing_code: code_field(raw), rate: Freight::Rate.parse(raw["rate"], raw["rate_currency"]))
  end

  def exchange_rate_records(section)
    records = []
    seen = {}
    section.each do |date_text, currencies|
      reject_on_error("exchange_rates", date_text, currencies) do
        date = date_field(date_text, "exchange rate date")
        raise RecordError, "rates of a date must be an object" unless currencies.is_a?(Hash)

        currencies.each do |currency, value|
          reject_on_error("exchange_rates", "#{date_text}/#{currency}", value) do
            record = exchange_rate_record(date, currency, value)
            key = [ record.date, record.currency ]
            raise RecordError, "duplicate exchange rate for #{record.currency} on #{record.date}" if seen[key]

            seen[key] = true
            records << record
          end
        end
      end
    end
    records
  end

  def exchange_rate_record(date, currency, value)
    code = currency.to_s.strip.downcase
    raise RecordError, "invalid currency #{currency.inspect}" unless CURRENCY_FORMAT.match?(code)
    raise RecordError, "exchange rate must be a number" unless value.is_a?(BigDecimal) || value.is_a?(Integer)

    amount = BigDecimal(value)
    raise RecordError, "exchange rate must be positive" unless amount.positive?
    unless amount == amount.round(EXCHANGE_RATE_SCALE) && amount < EXCHANGE_RATE_LIMIT
      raise RecordError, "exchange rate #{value} does not fit #{EXCHANGE_RATE_SCALE} decimal places"
    end

    ExchangeRateRecord.new(date: date, currency: code, rate: amount)
  end

  def code_field(raw)
    code = raw["sailing_code"]
    raise RecordError, "invalid sailing_code #{code.inspect}" unless code.is_a?(String) && CODE_FORMAT.match?(code)

    code
  end

  def port_field(value, name)
    code = Freight::PortCode.normalize(value)
    raise RecordError, "invalid #{name} #{value.inspect}" unless value.is_a?(String) && Freight::PortCode.valid?(code)

    code
  end

  def date_field(value, name)
    raise RecordError, "invalid #{name} #{value.inspect}" unless value.is_a?(String)

    Date.iso8601(value)
  rescue Date::Error
    raise RecordError, "invalid #{name} #{value.inspect}"
  end
end
