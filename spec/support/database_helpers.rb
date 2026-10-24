module DatabaseHelpers
  # Lets a statement fail in the database without aborting the surrounding test transaction.
  def within_savepoint(&block)
    ApplicationRecord.transaction(requires_new: true, &block)
  end

  # Removes committed data for specs that cannot use transactional tests (threads).
  def truncate_all_tables
    database = ApplicationRecord.connection.current_database
    raise "refusing to truncate #{database}" unless database.end_with?("_test")

    connection = ApplicationRecord.connection
    tables = connection.tables - %w[ schema_migrations ar_internal_metadata ]
    connection.execute("TRUNCATE #{tables.map { |table| connection.quote_table_name(table) }.join(", ")} RESTART IDENTITY CASCADE")
  end
end

RSpec.configure { |config| config.include DatabaseHelpers }
