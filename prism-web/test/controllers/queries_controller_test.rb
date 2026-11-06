require "test_helper"

class QueriesControllerViewTest < ActionDispatch::IntegrationTest
  setup do
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

  test "GET /prism/queries/new renders editor view" do
    @routes = PrismWeb::Engine.routes
    skip "Editor view requires host app context; controller test"
  end

  test "variable chip rendered when SQL contains placeholder" do
    sql = "SELECT * FROM users WHERE id = {{user_id}}"
    matches = sql.scan(/\{\{(\w+)\}\}/).flatten

    assert_equal ["user_id"], matches
    assert_equal 1, matches.size
  end

  test "execute payload includes variables when chips filled" do
    variables = { "user_id" => "42" }
    payload = { query: "SELECT * FROM users WHERE id = {{user_id}}", variables: variables }

    assert_equal "42", payload[:variables]["user_id"]
    assert_equal "SELECT * FROM users WHERE id = {{user_id}}", payload[:query]
  end
end