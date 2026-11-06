require "test_helper"

class SavedQueriesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get prism_web.saved_queries_url
    assert_response :success
  end

  test "should create saved query" do
    assert_difference("PrismWeb::SavedQuery.count") do
      post prism_web.saved_queries_url, params: {
        saved_query: {
          name: "Test Query",
          sql: "SELECT 1",
          visibility: "owner"
        }
      }
    end
  end

  test "should show saved query" do
    saved_query = PrismWeb::SavedQuery.create!(
      name: "Test Query",
      sql: "SELECT 1",
      visibility: "owner",
      owner_type: "User",
      owner_id: 1
    )

    get prism_web.saved_query_url(saved_query)
    assert_response :success
  end
end