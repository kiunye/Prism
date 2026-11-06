ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "rails/test_help"
require "minitest/mock"

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

class ActionDispatch::IntegrationTest
  FakeQueryEngine = Struct.new(:received) do
    def execute(sql, **options)
      self.received = [sql, options]
      Prism::Core::QueryResult.new(
        rows: [{ "n" => "42" }], columns: %w[n], row_count: 1, duration_ms: 1.5,
        truncated: false, query_id: "q-1", connection_slug: "primary"
      )
    end

    def explain(sql, **options)
      self.received = [sql, options]
      Prism::Core::ExplainResult.new(plan_json: [{ "Plan" => { "Total Cost" => 1.0 } }], estimated_cost: 1.0, warnings: [])
    end
  end

  FakeSchemaInspector = Struct.new(:unused) do
    def tables(_slug, owner: nil) = %w[orders users]
    def columns(_slug, table, owner: nil) = [{ name: "id", type: "integer" }]
    def indexes(_slug, table, owner: nil) = []
    def foreign_keys(_slug, _tables, owner: nil) = []
    def sample_rows(_slug, table, owner: nil) = []
  end

  def json
    JSON.parse(response.body)
  end
end
