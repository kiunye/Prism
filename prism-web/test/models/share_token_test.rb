require "test_helper"

class ShareTokenTest < ActiveSupport::TestCase
  def setup
    @share_token = PrismWeb::ShareToken.new(
      token: SecureRandom.hex(32),
      resource_type: "PrismWeb::SavedQuery",
      resource_id: 1
    )
  end

  test "should be valid" do
    assert @share_token.valid?
  end

  test "should generate token on create" do
    share_token = PrismWeb::ShareToken.create!(
      resource_type: "PrismWeb::SavedQuery",
      resource_id: 1
    )
    assert share_token.token.present?
  end

  test "should be accessible when expires_at is nil" do
    @share_token.expires_at = nil
    @share_token.save!
    assert @share_token.accessible?
  end

  test "should be accessible when expires_at is in future" do
    @share_token.expires_at = 1.hour.from_now
    @share_token.save!
    assert @share_token.accessible?
  end

  test "should not be accessible when expired" do
    @share_token.save!
    @share_token.update_column(:expires_at, 1.hour.ago)

    assert_not @share_token.accessible?
  end

  test "cannot be created already expired" do
    @share_token.expires_at = 1.hour.ago

    assert_not @share_token.valid?
  end
end