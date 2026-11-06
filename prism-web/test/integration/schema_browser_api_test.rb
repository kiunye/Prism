require "test_helper"

class SchemaBrowserApiTest < ActionDispatch::IntegrationTest
  test "schema lists visible tables" do
    Prism::Core::SchemaInspector.stub(:new, FakeSchemaInspector.new) do
      get "/prism/api/v1/connections/primary/schema", as: :json
    end

    assert_response :success
    assert_equal %w[orders users], json["data"].map { |t| t["name"] }
  end

  test "table endpoint returns columns, indexes and foreign keys" do
    Prism::Core::SchemaInspector.stub(:new, FakeSchemaInspector.new) do
      get "/prism/api/v1/connections/primary/tables/users", as: :json
    end

    assert_response :success
    assert_equal "users", json.dig("data", "name")
    assert_equal "id", json.dig("data", "columns", 0, "name")
  end
end

class VisibilityFilterTest < ActiveSupport::TestCase
  OWNER = { id: 1, type: "User" }.freeze

  test "allowlist keeps only allowed tables" do
    config = Prism::Configuration.new
    config.visibility.mode = :allowlist
    config.visibility.allowlist = Set.new(%w[users orders])

    assert_equal %w[orders users], config.visibility.filter(:test, OWNER, %w[users orders secret_table])
  end

  test "denylist removes denied tables" do
    config = Prism::Configuration.new
    config.visibility.mode = :denylist
    config.visibility.denylist = Set.new(%w[secret_table])

    assert_equal %w[orders users], config.visibility.filter(:test, OWNER, %w[users orders secret_table])
  end

  test "dynamic mode asks the resolver" do
    config = Prism::Configuration.new
    config.visibility.mode = :dynamic
    config.visibility.resolver = ->(_slug, _owner, actual) { actual & %w[users] }

    assert_equal %w[users], config.visibility.filter(:test, OWNER, %w[users orders secret_table])
  end

  test "prism storage tables are hidden even when allowlisted" do
    config = Prism::Configuration.new
    config.visibility.mode = :allowlist
    config.visibility.allowlist = Set.new(%w[users prism_saved_queries])

    assert_equal %w[users], config.visibility.filter(:test, OWNER, %w[users prism_saved_queries])
  end
end
