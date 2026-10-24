class CreateImportIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :import_issues do |t|
      t.references :feed_import, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :reference
      t.text :reason, null: false
      t.jsonb :details, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_check_constraint :import_issues,
                         "kind IN ('rejected_record', 'sailing_conflict', 'rate_conflict', 'unpriced', 'orphan_rate')",
                         name: "import_issues_kind_check"
  end
end
