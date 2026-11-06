require "test_helper"

class SchemaBrowserControllerTest < ActionDispatch::IntegrationTest
  setup do
    @routes = PrismWeb::Engine.routes
    Prism.configure do |c|
      c.connection :test do |conn|
        conn.adapter = :postgresql
        conn.credentials_file = Pathname.new("test/fixtures/secrets/database.yml")
        conn.read_only_role = "prism_ro"
        conn.default = true
      end
    end
    Prism.config.owner_resolver = ->(req) { { id: 1, type: "User" } }
    Prism.config.auth_guard = ->(req) { true }
  end

  test "GET /prism/ renders schema index with turbo-frame" do
    skip "Mounted engine requires host app; controller test verifies partial rendering"
  end

  test "GET /prism/api/v1/connections/test/schema returns tables array envelope" do
    skip "Requires live DB"
  end

  test "GET /prism/api/v1/connections/test/tables/users returns columns envelope" do
    skip "Requires live DB"
  end

  test "visibility allowlist filters actual DB tables against allowed set" do
    config = Prism::Configuration.new
    config.visibility.mode = :allowlist
    config.visibility.allowlist = Set.new(%w[users orders])

    actual = %w[users orders secret_table]
    tables = config.visibility.filter(:test, { id: 1, type: "User" }, actual)
    assert_includes tables, "users"
    assert_includes tables, "orders"
    assert_not_includes tables, "secret_table"
  end

  test "visibility denylist removes denylisted tables from actual set" do
    config = Prism::Configuration.new
    config.visibility.mode = :denylist
    config.visibility.denylist = Set.new(%w[secret_table])

    actual = %w[users orders secret_table]
    tables = config.visibility.filter(:test, { id: 1, type: "User" }, actual)
    assert_includes tables, "users"
    assert_includes tables, "orders"
    assert_not_includes tables, "secret_table"
  end

  test "visibility dynamic calls resolver with actual tables" do
    config = Prism::Configuration.new
    config.visibility.mode = :dynamic
    config.visibility.resolver = ->(slug, owner, actual) { actual & %w[users] }

    actual = %w[users orders secret_table]
    tables = config.visibility.filter(:test, { id: 1, type: "User" }, actual)
    assert_equal %w[users], tables
  end

  test "clicking a table button renders table schema" do
    skip "Pure system test requires Capybara; skipping in bare test run"
  end
end