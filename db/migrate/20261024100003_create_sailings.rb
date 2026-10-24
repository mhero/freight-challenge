class CreateSailings < ActiveRecord::Migration[8.1]
  def change
    create_table :sailings do |t|
      t.string :sailing_code, null: false
      t.string :origin_port, null: false
      t.string :destination_port, null: false
      t.date :departure_date, null: false
      t.date :arrival_date, null: false
      t.boolean :active, null: false, default: true
      t.references :first_import, null: false, foreign_key: { to_table: :feed_imports }
      t.references :last_seen_import, null: false, foreign_key: { to_table: :feed_imports }
      t.timestamps
    end

    add_index :sailings, :sailing_code, unique: true
    add_index :sailings, [ :origin_port, :departure_date ]
    add_index :sailings, :destination_port
    add_check_constraint :sailings, "arrival_date >= departure_date", name: "sailings_dates_check"
  end
end
