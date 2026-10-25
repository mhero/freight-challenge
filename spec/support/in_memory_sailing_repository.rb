# Test double for Freight::SailingRepository: the same contract as the database adapter,
# computed in plain Ruby. Records which origins were loaded.
class InMemorySailingRepository
  include Freight::SailingRepository

  attr_reader :loaded_origins

  def initialize(sailings)
    @sailings = sailings
    @loaded_origins = []
  end

  def reachable_from(origin)
    @loaded_origins << origin
    by_origin = @sailings.group_by(&:origin_port)
    reached = {}
    pending = by_origin.fetch(origin, []).dup

    until pending.empty?
      sailing = pending.shift
      next if reached.key?(sailing.code)

      reached[sailing.code] = sailing
      by_origin.fetch(sailing.destination_port, []).each do |next_sailing|
        pending << next_sailing if next_sailing.departure_date >= sailing.arrival_date
      end
    end
    reached.values.sort_by { |sailing| [ sailing.departure_date, sailing.code ] }
  end

  def known_ports(codes)
    codes.select do |code|
      @sailings.any? { |sailing| [ sailing.origin_port, sailing.destination_port ].include?(code) }
    end
  end
end
