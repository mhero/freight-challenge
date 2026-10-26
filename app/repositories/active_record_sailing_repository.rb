# Adapter between the domain and PostgreSQL. Only priced sailings leave it.
#
# reachable_from runs at most two queries, whatever the path length: one recursive CTE for the
# sailings and one for the exchange rates of the departure dates involved. Both run in one
# transaction (a single snapshot, so a concurrent import is seen completely or not at all) with a
# statement timeout. Conversion to EUR happens here in Ruby, in one place (Freight::ExchangeRates).
class ActiveRecordSailingRepository
  include Freight::SailingRepository

  DEFAULT_TIMEOUT_MS = 30_000

  def self.default_timeout_ms
    Integer(ENV.fetch("SEARCH_STATEMENT_TIMEOUT_MS", DEFAULT_TIMEOUT_MS))
  end

  def initialize(statement_timeout_ms: self.class.default_timeout_ms)
    @statement_timeout_ms = Integer(statement_timeout_ms)
  end

  def reachable_from(origin)
    within_snapshot do
      rows = Sailing.reachable_priced(origin).cast_values
      next [] if rows.empty?

      exchange_rates = ExchangeRate.table_for(rows.map { |row| as_date(row[3]) }.uniq)
      rows.filter_map { |row| to_domain(row, exchange_rates) }
    end
  rescue ActiveRecord::QueryCanceled, ActiveRecord::StatementTimeout
    raise Freight::SearchTimeout, "search exceeded its time limit (#{@statement_timeout_ms} ms); no route returned"
  end

  def known_ports(codes)
    Sailing.known_ports(codes.uniq)
  end

  private

  # A fresh connection gets a repeatable-read transaction. Inside a caller's transaction it simply joins it.
  def within_snapshot(&block)
    options = ApplicationRecord.connection.transaction_open? ? {} : { isolation: :repeatable_read }
    ApplicationRecord.transaction(**options) do
      ApplicationRecord.connection.execute(
        ApplicationRecord.sanitize_sql_array([ "SET LOCAL statement_timeout = ?", Integer(@statement_timeout_ms) ])
      )
      block.call
    end
  end

  # Row order: sailing_code, origin_port, destination_port, departure_date, arrival_date, rate_amount, rate_currency.
  def to_domain(row, exchange_rates)
    code, origin, destination, departure, arrival, amount, currency = row
    rate = Freight::Rate.new(amount_text: amount, currency: currency)
    departure = as_date(departure)
    price = exchange_rates.to_eur(rate, on: departure)
    return if price.nil?

    Freight::Sailing.new(
      code: code, origin_port: origin, destination_port: destination,
      departure_date: departure, arrival_date: as_date(arrival), rate: rate, price_eur: price
    )
  end

  def as_date(value)
    value.is_a?(Date) ? value : Date.iso8601(value.to_s)
  end
end
