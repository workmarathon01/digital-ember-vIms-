class PushNotificationJob < ApplicationJob
  queue_as :default

  # Misconfiguration will not fix itself by retrying; auth/network problems may.
  discard_on Fcm::ConfigurationError
  retry_on Fcm::AuthenticationError, wait: 30.seconds, attempts: 2
  retry_on Fcm::TransientError, wait: :polynomially_longer, attempts: 3

  def perform(targets, payload)
    records = load_targets(targets)
    return if records.empty?

    PushDelivery.call(records: records, payload: payload)
  end

  private

  # Targets carry the user id that owned the device when the notification was
  # enqueued. Re-checking it prevents a queued message from leaking to a
  # different account that signed in on the same device in the meantime.
  def load_targets(targets)
    Array(targets).filter_map do |target|
      id = target["id"] || target[:id]
      user_id = target["user_id"] || target[:user_id]
      next if id.blank? || user_id.blank?

      PushToken.enabled.find_by(id: id, user_id: user_id)
    end
  end
end
