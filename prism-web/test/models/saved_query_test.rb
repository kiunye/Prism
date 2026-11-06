require "test_helper"

class SavedQueryTest < ActiveSupport::TestCase
  def setup
    @saved_query = PrismWeb::SavedQuery.new(
      name: "Test Query",
      sql: "SELECT 1",
      visibility: "owner",
      owner_type: "User",
      owner_id: 1
    )
  end

  test "should be valid" do
    assert @saved_query.valid?
  end

  test "should require name" do
    @saved_query.name = nil
    assert_not @saved_query.valid?
  end

  test "should require sql" do
    @saved_query.sql = nil
    assert_not @saved_query.valid?
  end

  test "variables should default to empty hash" do
    @saved_query.save!
    assert_equal({}, @saved_query.variables)
  end

  test "accessible_by_owner? should return true for matching owner" do
    owner = { id: 1, type: "User" }
    @saved_query.save!
    assert @saved_query.accessible_by_owner?(owner)
  end

  test "accessible_by_owner? should return false for non-matching owner" do
    owner = { id: 2, type: "User" }
    @saved_query.save!
    assert_not @saved_query.accessible_by_owner?(owner)
  end
end