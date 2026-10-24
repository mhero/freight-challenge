class CreateFulfillmentEvents < ActiveRecord::Migration[8.1]
  def change
    # Outbox: one event per fulfilled search, read and acknowledged by the client.
    create_table :fulfillment_events do |t|
      t.references :saved_search, null: false, foreign_key: true, index: { unique: true }
      t.references :feed_import, null: false, foreign_key: true
      t.jsonb :payload, null: false, default: {}
      t.datetime :acknowledged_at
      t.timestamps
    end

    add_index :fulfillment_events, [ :acknowledged_at, :id ]
  end
end
