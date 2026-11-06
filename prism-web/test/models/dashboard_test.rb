require "test_helper"

class DashboardTest < ActiveSupport::TestCase
  def setup
    @dashboard = PrismWeb::Dashboard.new(
      name: "Test Dashboard",
      owner_type: "User",
      owner_id: 1
    )
  end

  test "should be valid" do
    assert @dashboard.valid?
  end

  test "should require name" do
    @dashboard.name = nil
    assert_not @dashboard.valid?
  end

  test "grid_layout should default to empty array" do
    @dashboard.save!
    assert_equal([], @dashboard.grid_layout)
  end

  test "filters should default to empty hash" do
    @dashboard.save!
    assert_equal({}, @dashboard.filters)
  end
end