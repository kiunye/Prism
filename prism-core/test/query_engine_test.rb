# frozen_string_literal: true

require "test_helper"

class QueryEngineTest < Minitest::Test
  FakeResult = Struct.new(:rows, :fields) do
    include Enumerable

    def each(&block) = rows.each(&block)
  end

  class FakeConnection
    attr_reader :statements, :params

    def initialize(result: FakeResult.new([{ "n" => "1" }], ["n"]), error: nil)
      @statements = []
      @result = result
      @error = error
    end

    def exec(sql)
      @statements << sql
    end

    def exec_params(sql, params)
      @statements << sql
      @params = params
      raise @error if @error

      @result
    end
  end

  class FakeManager
    attr_reader :connection, :checkouts

    def initialize(connection)
      @connection = connection
      @checkouts = 0
    end

    def default_slug = "primary"

    def with_connection(_slug = nil)
      @checkouts += 1
      yield @connection
    end
  end

  def setup
    @connection = FakeConnection.new
    @manager = FakeManager.new(@connection)
    @engine = Prism::Core::QueryEngine.new(connection_manager: @manager)
  end

  def test_write_statement_is_rejected_before_reaching_the_database
    error = assert_raises(Prism::QueryError) { @engine.execute("DELETE FROM users") }

    assert_equal :statement_rejected, error.code
    assert_equal 0, @manager.checkouts
  end

  def test_multi_statement_input_is_rejected_by_the_parser_before_reaching_the_database
    error = assert_raises(Prism::QueryError) { @engine.execute("SELECT 1; SELECT 2") }

    assert_equal :statement_rejected, error.code
    assert_equal 0, @manager.checkouts
  end

  def test_variables_are_bound_not_interpolated
    @engine.execute(
      "SELECT n FROM t WHERE n > {{min}}",
      variables: [{ name: "min", type: :integer }],
      values: { "min" => "7" }
    )

    assert_equal "BEGIN READ ONLY", @connection.statements.first
    assert_includes @connection.statements, "SELECT n FROM t WHERE n > $1"
    assert_equal [7], @connection.params
    assert_equal "COMMIT", @connection.statements.last
  end

  def test_row_limit_is_enforced
    rows = Array.new(3) { { "n" => "1" } }
    manager = FakeManager.new(FakeConnection.new(result: FakeResult.new(rows, ["n"])))
    engine = Prism::Core::QueryEngine.new(connection_manager: manager, max_rows: 2)

    error = assert_raises(Prism::QueryError) { engine.execute("SELECT n FROM t") }

    assert_equal :row_limit, error.code
  end

  def test_timeout_is_reported_as_a_timeout
    manager = FakeManager.new(FakeConnection.new(error: PG::QueryCanceled.new("canceling")))
    engine = Prism::Core::QueryEngine.new(connection_manager: manager)

    error = assert_raises(Prism::QueryError) { engine.execute("SELECT 1") }

    assert_equal :timeout, error.code
  end
end
