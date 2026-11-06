require "test_helper"

class QueriesApiTest < ActionDispatch::IntegrationTest
  test "validate accepts a plain SELECT" do
    post "/prism/api/v1/queries/validate", params: { query: "SELECT 1" }, as: :json

    assert_response :success
    assert_equal true, json.dig("data", "valid")
  end

  test "validate rejects a write using the real core validator" do
    post "/prism/api/v1/queries/validate", params: { query: "DROP TABLE users" }, as: :json

    assert_response :success
    assert_equal false, json.dig("data", "valid")
  end

  test "execute rejects a write before any database is touched" do
    post "/prism/api/v1/queries/execute", params: { query: "DELETE FROM users" }, as: :json

    assert_response :bad_request
    assert json["errors"].any?
  end

  test "execute rejects stacked statements" do
    post "/prism/api/v1/queries/execute", params: { query: "SELECT 1; SELECT 2" }, as: :json

    assert_response :bad_request
  end

  test "execute returns rows and meta and passes placeholder values as bound values" do
    engine = FakeQueryEngine.new

    Prism::Core::QueryEngine.stub(:new, engine) do
      post "/prism/api/v1/queries/execute",
           params: { query: "SELECT {{n}}", variables: { n: "42" } }, as: :json
    end

    assert_response :success
    assert_equal [{ "n" => "42" }], json.dig("data", "rows")
    assert_equal 1, json.dig("meta", "row_count")
    assert_equal({ "n" => "42" }, engine.received.last[:values])
    assert_equal [{ name: "n", type: :string }], engine.received.last[:variables]
  end

  test "execute returns CSV when requested" do
    Prism::Core::QueryEngine.stub(:new, FakeQueryEngine.new) do
      post "/prism/api/v1/queries/execute", params: { query: "SELECT 42 AS n" },
           headers: { "Accept" => "text/csv" }, as: :json
    end

    assert_response :success
    assert_equal "n\n42\n", response.body
  end

  test "explain returns the plan" do
    Prism::Core::QueryEngine.stub(:new, FakeQueryEngine.new) do
      post "/prism/api/v1/queries/explain", params: { query: "SELECT 1" }, as: :json
    end

    assert_response :success
    assert_equal 1.0, json.dig("data", "estimated_cost")
  end
end
