require "test_helper"

class ApiV1IntegrationTest < ActionDispatch::IntegrationTest
  test "schema browser returns table list" do
    get "/prism/api/v1/connections/production/schema"
    assert_response :success

    json = JSON.parse(response.body)
    assert json.key?("data")
  end

  test "query validation endpoint" do
    post "/prism/api/v1/queries/validate", params: {
      query: "SELECT 1"
    }, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("data")
  end
end