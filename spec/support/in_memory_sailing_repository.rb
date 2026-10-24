# Test double for Freight::SailingRepository. Records which ports were expanded.
class InMemorySailingRepository
  include Freight::SailingRepository

  attr_reader :requested_ports

  def initialize(sailings)
    @sailings = sailings
    @requested_ports = []
  end

  def departures_from(port, on_or_after: nil)
    @requested_ports << port
    @sailings
      .select { |sailing| sailing.origin_port == port }
      .select { |sailing| on_or_after.nil? || sailing.departure_date >= on_or_after }
      .sort_by { |sailing| [ sailing.departure_date, sailing.code ] }
  end

  def known_port?(code)
    @sailings.any? { |sailing| [ sailing.origin_port, sailing.destination_port ].include?(code) }
  end
end
