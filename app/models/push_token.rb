# A single app installation that can receive Firebase Cloud Messaging (FCM)
# notifications.
#
# One user can own many rows (phone, tablet, web browser, ...). The `uuid` is
# generated and persisted by the mobile app for the lifetime of the
# installation, so the backend can target one exact device even when the same
# account is signed in on several devices.
class PushToken < ApplicationRecord
  MAX_TOKEN_LENGTH = 2048
  MAX_PRUNE_AGE = 60.days

  belongs_to :user

  normalizes :uuid, with: ->(value) { value.to_s.strip }
  normalizes :platform, with: ->(value) { value.to_s.strip.downcase.presence || "unknown" }

  validates :uuid, presence: true, length: { maximum: 255 }
  validates :token, presence: true, length: { maximum: MAX_TOKEN_LENGTH }
  validates :enabled, inclusion: { in: [ true, false ] }
  validates :platform, length: { maximum: 32 }
  validates :device_name, :app_version, :os_version, :locale, :timezone,
            length: { maximum: 128 }, allow_blank: true
  validates :uuid, uniqueness: true
  validates :token, uniqueness: true
  validate :token_fits_index

  scope :enabled, -> { where(enabled: true) }
  scope :recent, -> { order(last_seen_at: :desc) }

  class << self
    # Idempotent registration used by the mobile app on launch, after login and
    # whenever FCM rotates the token.
    #
    # - Same uuid + new token: updates the existing device row.
    # - New uuid + token already used by another row: moves the token to the new
    #   device and removes the stale row.
    # - Same uuid + different user: reassigns the device to the signed-in user.
    def register!(user:, uuid:, token:, platform: nil, device_name: nil, app_version: nil,
                  os_version: nil, locale: nil, timezone: nil)
      normalized_uuid = uuid.to_s.strip
      normalized_token = token.to_s.strip

      attributes = {
        user: user,
        token: normalized_token,
        platform: platform.presence || "unknown",
        device_name: device_name.presence,
        app_version: app_version.presence,
        os_version: os_version.presence,
        locale: locale.presence,
        timezone: timezone.presence
      }.compact

      attempts = 0
      begin
        transaction do
          # A token belongs to exactly one installation. Re-registering the same
          # account after a reinstall can move it to a new uuid, but a different
          # account must not silently steal a token that belongs to another
          # device. In that case the app should log out first (or reuse the same
          # uuid when switching accounts on the same device).
          if normalized_uuid.present? && normalized_token.present? && user.present?
            conflict = where(token: normalized_token).where.not(uuid: normalized_uuid).first
            if conflict.present? && conflict.user_id != user.id
              invalid = new(user: user, uuid: normalized_uuid, token: normalized_token, last_seen_at: Time.current)
              invalid.errors.add(:token, "is already registered to another account")
              raise ActiveRecord::RecordInvalid.new(invalid)
            end

            conflict&.delete
          end

          record = find_or_initialize_by(uuid: normalized_uuid)
          record.assign_attributes(attributes)
          record.enabled = true
          record.disabled_at = nil
          record.last_error = nil
          record.failed_count = 0
          record.last_seen_at = Time.current
          record.save!
          record
        end
      rescue ActiveRecord::RecordNotUnique
        # A concurrent launch/token refresh won the race. Retry against the
        # committed row instead of failing the request.
        attempts += 1
        retry if attempts < 3
        raise
      end
    end

    # Removes tokens that FCM has permanently rejected and that have not been
    # re-registered for a while. Safe to call from a recurring job.
    def prune!(before: MAX_PRUNE_AGE.ago)
      where(enabled: false).where("disabled_at < ?", before).delete_all
    end
  end

  def mark_seen!
    update_columns(last_seen_at: Time.current, updated_at: Time.current)
  end

  def disable!(reason: nil)
    update_columns(
      enabled: false,
      disabled_at: Time.current,
      last_error: reason.presence,
      updated_at: Time.current
    )
  end

  # Never expose the raw FCM token in list responses. The client already knows
  # it; the token is only needed server-side when sending.
  def as_api_json
    {
      uuid: uuid,
      platform: platform,
      device_name: device_name,
      app_version: app_version,
      os_version: os_version,
      locale: locale,
      timezone: timezone,
      enabled: enabled,
      last_seen_at: last_seen_at&.iso8601,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end

  private

  # The unique index on `token` is a btree index. Keeping the token within a
  # safe byte size avoids a database-level index row error for hostile input.
  def token_fits_index
    return if token.blank? || token.to_s.bytesize <= MAX_TOKEN_LENGTH

    errors.add(:token, "is too long")
  end
end
