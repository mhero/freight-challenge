# Adapter between the domain and PostgreSQL. Only priced sailings leave it.
class ActiveRecordSailingRepository
  include Freight::SailingRepository

  def departures_from(port, on_or_after: nil)
    rows = Sailing.priced_departures(port, on_or_after: on_or_after).to_a
    return [] if rows.empty?

    exchange_rates = ExchangeRate.table_for(rows.map(&:departure_date).uniq)
    rows.filter_map { |row| to_domain(row, exchange_rates) }
  end

  def known_port?(code)
    Sailing.active.where(origin_port: code).or(Sailing.active.where(destination_port: code)).exists?
  end

  private

  def to_domain(row, exchange_rates)
    rate = Freight::Rate.new(amount_text: row[:rate_amount], currency: row[:rate_currency])
    price = exchange_rates.to_eur(rate, on: row.departure_date)
    return if price.nil?

    Freight::Sailing.new(
      code: row.sailing_code, origin_port: row.origin_port, destination_port: row.destination_port,
      departure_date: row.departure_date, arrival_date: row.arrival_date, rate: rate, price_eur: price
    )
  end
end
