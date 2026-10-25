class AddActiveDeparturesIndexToSailings < ActiveRecord::Migration[8.1]
  def change
    # Serves Sailing.priced_departures: active sailings of a port from a date, already in the
    # (departure_date, sailing_code) order the search needs. Inactive history stays out of the index.
    add_index :sailings, [ :origin_port, :departure_date, :sailing_code ],
              where: "active", name: "index_sailings_on_active_departures"
  end
end
