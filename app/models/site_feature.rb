class SiteFeature < ApplicationRecord
  include Auditable

  belongs_to :site, inverse_of: :site_features
  belongs_to :feature, inverse_of: :site_features
  belongs_to :enabled_by, class_name: "User", optional: true

  validates :feature_id, uniqueness: { scope: :site_id }

  scope :enabled, -> { where(enabled: true) }

  before_save :stamp_enabled_at, if: :will_save_change_to_enabled?

  def to_s
    "#{site&.name} · #{feature&.name}"
  end

  private

  def stamp_enabled_at
    self.enabled_at = enabled? ? Time.current : nil
  end
end
