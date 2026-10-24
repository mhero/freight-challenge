class CreateSavedSearches < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_searches do |t|
      t.string :origin_port, null: false
      t.string :destination_port, null: false
      t.string :criterion, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :fulfilled_at
      t.references :fulfilled_import, foreign_key: { to_table: :feed_imports }
      t.timestamps
    end

    # One pending search per origin, destination and criterion.
    add_index :saved_searches, [ :origin_port, :destination_port, :criterion ], unique: true,
              where: "status = 'pending'", name: "index_saved_searches_on_pending_query"
    add_index :saved_searches, [ :status, :id ]
    add_check_constraint :saved_searches, "status IN ('pending', 'fulfilled')", name: "saved_searches_status_check"
  end
end
