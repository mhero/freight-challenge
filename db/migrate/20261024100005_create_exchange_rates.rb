class CreateExchangeRates < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rates do |t|
      t.date :date, null: false
      t.string :currency, null: false
      t.decimal :rate, precision: 18, scale: 8, null: false
      t.references :import, null: false, foreign_key: { to_table: :feed_imports }
      t.timestamps
    end

    add_index :exchange_rates, [ :date, :currency ], unique: true
    add_check_constraint :exchange_rates, "rate > 0", name: "exchange_rates_rate_check"
    add_check_constraint :exchange_rates, "currency = lower(currency)", name: "exchange_rates_currency_check"
  end
end
