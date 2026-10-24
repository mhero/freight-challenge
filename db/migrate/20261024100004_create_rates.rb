class CreateRates < ActiveRecord::Migration[8.1]
  def change
    # Append-only: one row per sailing and import, amount kept as received.
    create_table :rates do |t|
      t.references :sailing, null: false, foreign_key: true
      t.references :import, null: false, foreign_key: { to_table: :feed_imports }
      t.string :amount, null: false
      t.string :currency, null: false
      t.datetime :created_at, null: false
    end

    add_index :rates, [ :sailing_id, :import_id ], unique: true
    add_check_constraint :rates, "currency = upper(currency)", name: "rates_currency_check"
  end
end
