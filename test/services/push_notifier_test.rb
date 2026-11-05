require "test_helper"

class PushNotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @user = User.create!(
      firstname: "Push", lastname: "Notifier", email: "push-notifier-#{SecureRandom.hex(4)}@example.test",
      password: "StrongPass!2026"
    )
  end

  test "builds a notification and stringifies structured data" do
    payload = PushNotifier.build_payload(
      title: "Visitor arrived",
      body: "Ravi is at Gate 2",
      data: { visitor_id: 42, urgent: true, meta: { gate: "2" } },
      deep_link: "myapp://visitors/42"
    )

    assert_equal "Visitor arrived", payload.dig("notification", "title")
    assert_equal "42", payload.dig("data", "visitor_id")
    assert_equal "true", payload.dig("data", "urgent")
    assert_equal({ "gate" => "2" }.to_json, payload.dig("data", "meta"))
    assert_equal "myapp://visitors/42", payload.dig("data", "link")
    assert_equal "high", payload.dig("android", "priority")
    assert_equal "10", payload.dig("apns", "headers", "apns-priority")
  end

  test "silent payloads omit the visible notification" do
    payload = PushNotifier.build_payload(
      data: { sync: "1" },
      silent: true
    )

    assert_not payload.key?("notification")
    assert_not payload.dig("android", "notification")
    assert_equal "background", payload.dig("apns", "headers", "apns-push-type")
    assert_equal 1, payload.dig("apns", "payload", "aps", "content-available")
  end

  test "deep links are only used as web push links when they are https urls" do
    custom = PushNotifier.build_payload(title: "Hi", deep_link: "myapp://visitors/42")
    insecure = PushNotifier.build_payload(title: "Hi", deep_link: "http://example.test/visitors/42")
    web = PushNotifier.build_payload(title: "Hi", deep_link: "https://example.test/visitors/42")

    assert_not custom.dig("webpush", "fcm_options", "link")
    assert_not insecure.dig("webpush", "fcm_options", "link")
    assert_equal "https://example.test/visitors/42", web.dig("webpush", "fcm_options", "link")
  end

  test "platform overrides are deep merged into the generated payload" do
    payload = PushNotifier.build_payload(
      title: "Hi",
      android: { "notification" => { "channel_id" => "custom-channel" } },
      apns: { "headers" => { "apns-priority" => "5" } }
    )

    assert_equal "high", payload.dig("android", "priority")
    assert_equal "custom-channel", payload.dig("android", "notification", "channel_id")
    assert_equal "5", payload.dig("apns", "headers", "apns-priority")
    assert_equal "alert", payload.dig("apns", "headers", "apns-push-type")
  end

  test "deliver_to_user enqueues a job targeting every enabled device" do
    phone = PushToken.register!(user: @user, uuid: "phone", token: "phone-token")
    tablet = PushToken.register!(user: @user, uuid: "tablet", token: "tablet-token")
    PushToken.register!(user: @user, uuid: "disabled", token: "disabled-token").update!(enabled: false)

    assert_enqueued_with(job: PushNotificationJob) do
      PushNotifier.deliver_to_user(@user, title: "Hello", body: "World")
    end

    job = enqueued_jobs.last
    targets = job[:args].first
    assert_equal [ phone.id, tablet.id ].sort, targets.map { |target| target["id"] || target[:id] }.sort
  end

  test "deliver_to_user can target one device uuid" do
    PushToken.register!(user: @user, uuid: "phone", token: "phone-token")
    tablet = PushToken.register!(user: @user, uuid: "tablet", token: "tablet-token")

    PushNotifier.deliver_to_user(@user, title: "Hello", uuid: "tablet")

    targets = enqueued_jobs.last[:args].first
    assert_equal [ tablet.id ], targets.map { |target| target["id"] || target[:id] }
  end

  test "deliver_to_user does nothing when the user has no enabled devices" do
    assert_no_enqueued_jobs do
      assert_equal [], PushNotifier.deliver_to_user(@user, title: "Hello")
    end
  end
end
