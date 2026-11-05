require "test_helper"

class PushNotificationJobTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      firstname: "Job", lastname: "Push", email: "job-push-#{SecureRandom.hex(4)}@example.test",
      password: "StrongPass!2026"
    )
  end

  test "delivers only to devices that still belong to the enqueued user" do
    device = PushToken.register!(user: @user, uuid: "device-1", token: "token-1")
    other = User.create!(
      firstname: "Other", lastname: "Job", email: "other-job-#{SecureRandom.hex(4)}@example.test",
      password: "StrongPass!2026"
    )

    # Simulate the same device signing into a different account after the job
    # was enqueued.
    device.update!(user: other)

    delivered = nil
    fake = lambda do |records:, payload:|
      delivered = [ records.map(&:id), payload ]
      []
    end

    with_stubbed_method(PushDelivery, :call, fake) do
      PushNotificationJob.perform_now([ { "id" => device.id, "user_id" => @user.id } ], { "notification" => {} })
    end

    assert_nil delivered
  end

  test "delivers to a matching device" do
    device = PushToken.register!(user: @user, uuid: "device-1", token: "token-1")

    delivered = nil
    fake = lambda do |records:, payload:|
      delivered = [ records.map(&:id), payload ]
      []
    end

    with_stubbed_method(PushDelivery, :call, fake) do
      PushNotificationJob.perform_now(
        [ { "id" => device.id, "user_id" => @user.id } ],
        { "notification" => { "title" => "Hi" } }
      )
    end

    assert_equal [ device.id ], delivered.first
    assert_equal "Hi", delivered.last.dig("notification", "title")
  end
end
