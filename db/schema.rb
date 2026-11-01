# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_25_100001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "exchange_rates", force: :cascade do |t|
    t.date "date", null: false
    t.string "currency", null: false
    t.decimal "rate", precision: 18, scale: 8, null: false
    t.bigint "import_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date", "currency"], name: "index_exchange_rates_on_date_and_currency", unique: true
    t.index ["import_id"], name: "index_exchange_rates_on_import_id"
    t.check_constraint "currency::text = lower(currency::text)", name: "exchange_rates_currency_check"
    t.check_constraint "rate > 0::numeric", name: "exchange_rates_rate_check"
  end

  create_table "feed_imports", force: :cascade do |t|
    t.string "source", null: false
    t.string "checksum", null: false
    t.string "status", default: "processing", null: false
    t.text "raw_payload", null: false
    t.jsonb "stats", default: {}, null: false
    t.text "error_message"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum"], name: "index_feed_imports_on_completed_checksum", unique: true, where: "((status)::text = 'completed'::text)"
    t.check_constraint "status::text = ANY (ARRAY['processing'::character varying, 'completed'::character varying, 'failed'::character varying]::text[])", name: "feed_imports_status_check"
  end

  create_table "fulfillment_events", force: :cascade do |t|
    t.bigint "saved_search_id", null: false
    t.bigint "feed_import_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "acknowledged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["acknowledged_at", "id"], name: "index_fulfillment_events_on_acknowledged_at_and_id"
    t.index ["feed_import_id"], name: "index_fulfillment_events_on_feed_import_id"
    t.index ["saved_search_id"], name: "index_fulfillment_events_on_saved_search_id", unique: true
  end

  create_table "import_issues", force: :cascade do |t|
    t.bigint "feed_import_id", null: false
    t.string "kind", null: false
    t.string "reference"
    t.text "reason", null: false
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["feed_import_id"], name: "index_import_issues_on_feed_import_id"
    t.check_constraint "kind::text = ANY (ARRAY['rejected_record'::character varying, 'sailing_conflict'::character varying, 'rate_conflict'::character varying, 'unpriced'::character varying, 'orphan_rate'::character varying]::text[])", name: "import_issues_kind_check"
  end

  create_table "rates", force: :cascade do |t|
    t.bigint "sailing_id", null: false
    t.bigint "import_id", null: false
    t.string "amount", null: false
    t.string "currency", null: false
    t.datetime "created_at", null: false
    t.index ["import_id"], name: "index_rates_on_import_id"
    t.index ["sailing_id", "import_id"], name: "index_rates_on_sailing_id_and_import_id", unique: true
    t.index ["sailing_id"], name: "index_rates_on_sailing_id"
    t.check_constraint "currency::text = upper(currency::text)", name: "rates_currency_check"
  end

  create_table "sailings", force: :cascade do |t|
    t.string "sailing_code", null: false
    t.string "origin_port", null: false
    t.string "destination_port", null: false
    t.date "departure_date", null: false
    t.date "arrival_date", null: false
    t.boolean "active", default: true, null: false
    t.bigint "first_import_id", null: false
    t.bigint "last_seen_import_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_port"], name: "index_sailings_on_destination_port"
    t.index ["first_import_id"], name: "index_sailings_on_first_import_id"
    t.index ["last_seen_import_id"], name: "index_sailings_on_last_seen_import_id"
    t.index ["origin_port", "departure_date", "sailing_code"], name: "index_sailings_on_active_departures", where: "active"
    t.index ["origin_port", "departure_date"], name: "index_sailings_on_origin_port_and_departure_date"
    t.index ["sailing_code"], name: "index_sailings_on_sailing_code", unique: true
    t.check_constraint "arrival_date >= departure_date", name: "sailings_dates_check"
  end

  create_table "saved_searches", force: :cascade do |t|
    t.string "origin_port", null: false
    t.string "destination_port", null: false
    t.string "criterion", null: false
    t.string "status", default: "pending", null: false
    t.datetime "fulfilled_at"
    t.bigint "fulfilled_import_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fulfilled_import_id"], name: "index_saved_searches_on_fulfilled_import_id"
    t.index ["origin_port", "destination_port", "criterion"], name: "index_saved_searches_on_pending_query", unique: true, where: "((status)::text = 'pending'::text)"
    t.index ["status", "id"], name: "index_saved_searches_on_status_and_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'fulfilled'::character varying]::text[])", name: "saved_searches_status_check"
  end

  add_foreign_key "exchange_rates", "feed_imports", column: "import_id"
  add_foreign_key "fulfillment_events", "feed_imports"
  add_foreign_key "fulfillment_events", "saved_searches"
  add_foreign_key "import_issues", "feed_imports"
  add_foreign_key "rates", "feed_imports", column: "import_id"
  add_foreign_key "rates", "sailings"
  add_foreign_key "sailings", "feed_imports", column: "first_import_id"
  add_foreign_key "sailings", "feed_imports", column: "last_seen_import_id"
  add_foreign_key "saved_searches", "feed_imports", column: "fulfilled_import_id"
end
