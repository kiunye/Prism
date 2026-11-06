require "test_helper"

class SchemaBrowserTest < ActionDispatch::SystemTestCase
  driven_by :rack_test

  test "schema browser loads tables" do
    visit "/prism/"
    assert_response :success
  end
end