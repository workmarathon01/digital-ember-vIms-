class UserFeature < ApplicationRecord
  include Auditable

  belongs_to :user, inverse_of: :user_features
  belongs_to :site, inverse_of: :user_features
  belongs_to :feature, inverse_of: :user_features
  belongs_to :granted_by, class_name: "User", optional: true

  validates :feature_id, uniqueness: { scope: %i[user_id site_id] }
  validate :feature_must_be_enabled_at_site, if: :enabled?

  scope :granted, -> { where(enabled: true) }
  scope :revoked, -> { where(enabled: false) }

  def to_s
    "#{user&.full_name} · #{site&.name} · #{feature&.name}"
  end

  private

  def feature_must_be_enabled_at_site
    return if site.blank? || feature.blank?
    return if site.site_features.enabled.exists?(feature_id: feature_id)

    errors.add(:feature, "must be enabled for the site before it can be granted to a user")
  end
end
