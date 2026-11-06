require "test_helper"

class QueriesApiTest < ActionDispatch::IntegrationTest
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

  test "POST validate returns valid envelope for SELECT 1" do
    skip "Requires live DB connection; requires stubbing connection manager"
  end

  test "POST execute returns rows + meta" do
    skip "Requires live DB"
  end

  test "POST explain returns plan_json" do
    skip "Requires live DB"
  end

  test "POST execute with Accept text/csv returns CSV body" do
    skip "Requires live DB + CSV format negotiation"
  end

  test "validates SQL against prism-core validator" do
    validator = Prism::StatementValidator.new
    result = validator.validate("SELECT 1")

    assert result.valid
    assert_empty result.errors if result.respond_to?(:errors)
  end

  test "rejects writes at prism-core layer" do
    validator = Prism::StatementValidator.new
    result = validator.validate("DROP TABLE users")

    assert_not result.valid
  end
end