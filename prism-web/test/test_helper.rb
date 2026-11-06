ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "rails/test_help"

# Prism targets Postgres; the dummy app runs on SQLite, which has no jsonb.
require "active_record/connection_adapters/sqlite3_adapter"
ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.alias_method :jsonb, :json

ActiveRecord::Migration.verbose = false
ActiveRecord::MigrationContext.new(PrismWeb::Engine.root.join("db/migrate")).migrate

class ActiveSupport::TestCase
  def setup
    Current[:owner] = { id: 1, type: "User" }
  end

  def teardown
    Current.reset
  end
end
