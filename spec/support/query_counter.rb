# Collects the SQL statements run by a block. Transaction control (BEGIN, COMMIT, SAVEPOINT...) and
# the per-transaction `SET LOCAL statement_timeout` are not data queries, so they are not counted.
module QueryCounter
  CONTROL_STATEMENT = /\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT|SET LOCAL)\b/i

  def queries_run
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA" || payload[:cached] || payload[:sql].match?(CONTROL_STATEMENT)

      statements << payload[:sql]
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end

RSpec.configure { |config| config.include QueryCounter }
