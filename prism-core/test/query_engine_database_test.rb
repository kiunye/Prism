# frozen_string_literal: true

require "test_helper"

# Runs against a real Postgres. Set PRISM_TEST_DATABASE_URL to a database whose
# user may only SELECT, e.g. postgres://prism_ro:secret@localhost/prism_test
class QueryEngineDatabaseTest < Minitest::Test
  class Manager
    def initialize(url) = @connection = PG.connect(url)

    def default_slug = "primary"

    def with_connection(_slug = nil)
      yield @connection
    end
  end

  def setup
    url = ENV["PRISM_TEST_DATABASE_URL"]
    skip "PRISM_TEST_DATABASE_URL not set" unless url

    @engine = Prism::Core::QueryEngine.new(connection_manager: Manager.new(url))
  end

  def test_select_with_variables_returns_rows
    result = @engine.execute(
      "SELECT {{n}}::int AS answer",
      variables: [{ name: "n", type: :integer }],
      values: { "n" => "42" }
    )

    assert_equal [{ "answer" => 42 }], result.rows
  end

  def test_write_that_slips_past_validation_is_refused_by_the_database
    manager = Manager.new(ENV.fetch("PRISM_TEST_DATABASE_URL"))

    error = assert_raises(PG::Error) do
      manager.with_connection do |conn|
        conn.exec("BEGIN READ ONLY")
        conn.exec("CREATE TEMP TABLE should_fail(id int)")
      end
    end

    assert_match(/read-only/i, error.message)
  end
end
