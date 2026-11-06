require "test_helper"

class SavedQueriesControllerTest < ActionDispatch::IntegrationTest
  def create_query(**attrs)
    PrismWeb::SavedQuery.create!({ name: "Q", sql: "SELECT 1", visibility: "owner", owner_type: "User", owner_id: 1 }.merge(attrs))
  end

  test "index lists only queries visible to the owner" do
    mine = create_query(name: "mine")
    create_query(name: "theirs", owner_id: 2)

    get "/prism/api/v1/saved_queries", as: :json

    assert_response :success
    assert_equal [mine.id], json["data"].map { |q| q["id"] }
  end

  test "create stores the query for the current owner" do
    assert_difference("PrismWeb::SavedQuery.count") do
      post "/prism/api/v1/saved_queries", params: { saved_query: { name: "Test", sql: "SELECT 1", visibility: "owner" } }, as: :json
    end

    assert_response :created
    assert_equal 1, PrismWeb::SavedQuery.last.owner_id
  end

  test "create reports validation errors" do
    post "/prism/api/v1/saved_queries", params: { saved_query: { name: "", sql: "" } }, as: :json

    assert_response :unprocessable_entity
  end

  test "show refuses another owner's private query" do
    other = create_query(owner_id: 2)

    get "/prism/api/v1/saved_queries/#{other.id}", as: :json

    assert_response :forbidden
  end

  test "execute runs the saved sql with bound values" do
    saved = create_query(sql: "SELECT {{n}}")
    engine = FakeQueryEngine.new

    Prism::Core::QueryEngine.stub(:new, engine) do
      post "/prism/api/v1/saved_queries/#{saved.id}/execute", params: { variables: { n: "42" } }, as: :json
    end

    assert_response :success
    assert_equal({ "n" => "42" }, engine.received.last[:values])
  end
end
