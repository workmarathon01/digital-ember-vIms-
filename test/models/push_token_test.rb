require "test_helper"

class PushTokenTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      firstname: "Push", lastname: "Owner", email: "push-owner-#{SecureRandom.hex(4)}@example.test",
      password: "StrongPass!2026"
    )
  end

  test "registers a device with a fresh token" do
    token = PushToken.register!(
      user: @user,
      uuid: "device-1",
      token: "fcm-token-1",
      platform: "Android",
      device_name: "Pixel 8",
      app_version: "1.0.0"
    )

    assert token.persisted?
    assert_equal @user, token.user
    assert_equal "device-1", token.uuid
    assert_equal "fcm-token-1", token.token
    assert_equal "android", token.platform
    assert token.enabled?
    assert token.last_seen_at.present?
  end

  test "re-registering the same uuid rotates the token in place" do
    original = PushToken.register!(user: @user, uuid: "device-1", token: "old-token")
    rotated = PushToken.register!(user: @user, uuid: "device-1", token: "new-token", app_version: "1.1.0")

    assert_equal original.id, rotated.id
    assert_equal "new-token", rotated.reload.token
    assert_equal "1.1.0", rotated.app_version
    assert_equal 1, PushToken.where(uuid: "device-1").count
  end

  test "a token that moved to another device uuid is removed from the old row" do
    stale = PushToken.register!(user: @user, uuid: "old-install", token: "same-token")
    moved = PushToken.register!(user: @user, uuid: "new-install", token: "same-token")

    assert_not PushToken.exists?(stale.id)
    assert_equal "new-install", moved.uuid
    assert_equal 1, PushToken.where(token: "same-token").count
  end

  test "a token owned by another account cannot be claimed on a different uuid" do
    other = User.create!(
      firstname: "Other", lastname: "Owner", email: "push-conflict-#{SecureRandom.hex(4)}@example.test",
      password: "StrongPass!2026"
    )
    PushToken.register!(user: other, uuid: "other-device", token: "shared-token")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      PushToken.register!(user: @user, uuid: "my-device", token: "shared-token")
    end

    assert_match(/already registered to another account/i, error.record.errors.full_messages.to_sentence)
    assert_equal other, PushToken.find_by(token: "shared-token").user
  end

  test "the same device uuid is reassigned when a different user signs in" do
    other = User.create!(
      firstname: "Other", lastname: "Owner", email: "push-other-#{SecureRandom.hex(4)}@example.test",
      password: "StrongPass!2026"
    )

    first = PushToken.register!(user: @user, uuid: "shared-tablet", token: "tablet-token")
    second = PushToken.register!(user: other, uuid: "shared-tablet", token: "tablet-token")

    assert_equal first.id, second.id
    assert_equal other, second.reload.user
    assert_equal 1, PushToken.where(uuid: "shared-tablet").count
  end

  test "uuid and token are unique" do
    PushToken.register!(user: @user, uuid: "device-1", token: "token-1")

    duplicate_uuid = PushToken.new(user: @user, uuid: "device-1", token: "token-2", last_seen_at: Time.current)
    duplicate_token = PushToken.new(user: @user, uuid: "device-2", token: "token-1", last_seen_at: Time.current)

    assert_not duplicate_uuid.valid?
    assert_not duplicate_token.valid?
  end

  test "api json never exposes the raw fcm token" do
    token = PushToken.register!(user: @user, uuid: "device-1", token: "secret-fcm-token")
    json = token.as_api_json

    assert_equal "device-1", json[:uuid]
    assert_not json.key?(:token)
    assert_not_includes json.values, "secret-fcm-token"
  end

  test "prune removes only old disabled tokens" do
    old_disabled = PushToken.register!(user: @user, uuid: "old-disabled", token: "old-disabled-token")
    old_disabled.update_columns(enabled: false, disabled_at: 61.days.ago, updated_at: 61.days.ago)

    fresh_disabled = PushToken.register!(user: @user, uuid: "fresh-disabled", token: "fresh-disabled-token")
    fresh_disabled.update_columns(enabled: false, disabled_at: 1.day.ago, updated_at: 1.day.ago)

    old_enabled = PushToken.register!(user: @user, uuid: "old-enabled", token: "old-enabled-token")
    old_enabled.update_columns(last_seen_at: 90.days.ago, updated_at: 90.days.ago)

    assert_equal 1, PushToken.prune!
    assert_not PushToken.exists?(old_disabled.id)
    assert PushToken.exists?(fresh_disabled.id)
    assert PushToken.exists?(old_enabled.id)
  end
end
