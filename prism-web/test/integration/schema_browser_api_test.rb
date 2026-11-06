require "test_helper"

class SchemaBrowserApiTest < ActionDispatch::IntegrationTest
  setup do
    Prism.configure do |c|
      c.connection :test do |conn|
        conn.adapter = :postgresql
        conn.reuse_host_pool = false
        conn.credentials_file = Pathname.new("test/fixtures/secrets/database.yml")
        conn.read_only_role = "prism_ro"
        conn.default = true
      end
    end

    Prism.config.owner_resolver = ->(req) { { id: 1, type: "User" } }
    Prism.config.auth_guard = ->(req) { true }
  end

  test "GET schema returns JSON envelope" do
    skip "Requires live DB connection"
  end
end