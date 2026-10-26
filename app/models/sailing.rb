class Sailing < ApplicationRecord
  # Every active, priced sailing reachable from an origin, found with one recursive query.
  # "Priced" is decided here: the sailing has a rate in the import that last saw it and, unless it is
  # in EUR, an exchange rate exists for its departure date. UNION drops duplicate rows, so cycles end.
  # Conversion to EUR is not done in SQL; the adapter does it in Ruby.
  REACHABLE_PRICED_SQL = <<~SQL.squish.freeze
    WITH RECURSIVE reachable (sailing_code, origin_port, destination_port, departure_date, arrival_date, rate_amount, rate_currency) AS (
      SELECT s.sailing_code, s.origin_port, s.destination_port, s.departure_date, s.arrival_date, r.amount, r.currency
      FROM sailings s
      JOIN rates r ON r.sailing_id = s.id AND r.import_id = s.last_seen_import_id
      WHERE s.active AND s.origin_port = ?
        AND (r.currency = 'EUR' OR EXISTS (
          SELECT 1 FROM exchange_rates x WHERE x.date = s.departure_date AND x.currency = lower(r.currency)))
      UNION
      SELECT n.sailing_code, n.origin_port, n.destination_port, n.departure_date, n.arrival_date, r.amount, r.currency
      FROM reachable p
      JOIN sailings n ON n.origin_port = p.destination_port AND n.departure_date >= p.arrival_date AND n.active
      JOIN rates r ON r.sailing_id = n.id AND r.import_id = n.last_seen_import_id
      WHERE r.currency = 'EUR' OR EXISTS (
        SELECT 1 FROM exchange_rates x WHERE x.date = n.departure_date AND x.currency = lower(r.currency))
    )
    SELECT * FROM reachable ORDER BY departure_date, sailing_code
  SQL

  KNOWN_PORTS_SQL = <<~SQL.squish.freeze
    SELECT ports.code FROM unnest(ARRAY[?]::text[]) AS ports(code)
    WHERE EXISTS (SELECT 1 FROM sailings WHERE active AND origin_port = ports.code)
       OR EXISTS (SELECT 1 FROM sailings WHERE active AND destination_port = ports.code)
  SQL

  belongs_to :first_import, class_name: "FeedImport"
  belongs_to :last_seen_import, class_name: "FeedImport"
  has_many :rates

  validates :sailing_code, :origin_port, :destination_port, :departure_date, :arrival_date, presence: true

  scope :active, -> { where(active: true) }

  # One query. Columns: sailing_code, origin_port, destination_port, departure_date, arrival_date,
  # rate_amount, rate_currency; ordered by departure date, then sailing code.
  def self.reachable_priced(origin)
    connection.select_all(sanitize_sql_array([ REACHABLE_PRICED_SQL, origin ]), "Sailing Reachable", [], preparable: false)
  end

  # One query for all codes: the ones that appear in an active sailing.
  def self.known_ports(codes)
    return [] if codes.empty?

    connection.select_all(sanitize_sql_array([ KNOWN_PORTS_SQL, codes ]), "Sailing Known Ports", [], preparable: false).rows.flatten
  end
end
