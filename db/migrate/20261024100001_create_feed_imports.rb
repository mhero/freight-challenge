class CreateFeedImports < ActiveRecord::Migration[8.1]
  def change
    create_table :feed_imports do |t|
      t.string :source, null: false
      t.string :checksum, null: false
      t.string :status, null: false, default: "processing"
      t.text :raw_payload, null: false
      t.jsonb :stats, null: false, default: {}
      t.text :error_message
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.timestamps
    end

    # A feed is imported once. Failed attempts may be retried, so only completed ones are unique.
    add_index :feed_imports, :checksum, unique: true, where: "status = 'completed'",
              name: "index_feed_imports_on_completed_checksum"
    add_check_constraint :feed_imports, "status IN ('processing', 'completed', 'failed')",
                         name: "feed_imports_status_check"
  end
end
