class Site < ApplicationRecord
  include Auditable

  before_destroy :prevent_destroy_with_residents

  has_many :buildings, dependent: :destroy, inverse_of: :site
  has_many :floors, through: :buildings
  has_many :units, through: :buildings
  has_many :user_sites, dependent: :restrict_with_error, inverse_of: :site
  has_many :users, through: :user_sites
  has_many :site_features, dependent: :destroy, inverse_of: :site
  has_many :features, through: :site_features
  has_many :user_features, dependent: :destroy, inverse_of: :site
  has_many :staffs, dependent: :restrict_with_error
  has_many :visitors, dependent: :restrict_with_error

  normalizes :code, with: ->(code) { code.to_s.strip.upcase }
  normalizes :name, with: ->(name) { name.to_s.strip.squish }

  before_validation :assign_code, if: -> { code.blank? }

  validates :name, presence: true, length: { maximum: 120 }
  validates :code, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[A-Z0-9][A-Z0-9_-]{1,23}\z/, message: "may use letters, numbers, dashes and underscores" }
  validates :latitude, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, allow_nil: true
  validates :longitude, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :search, lambda { |query|
    term = "%#{query.to_s.strip}%"
    where("sites.name ILIKE :term OR sites.code ILIKE :term OR sites.region ILIKE :term OR sites.city ILIKE :term", term: term)
  }

  def display_name
    [ name, region.presence ].compact.join(" · ")
  end

  def full_address
    [ address, city, state, postal_code, country ].compact_blank.join(", ")
  end

  def primary_residents
    user_sites.where(is_primary: true).includes(:user, :unit)
  end

  def enabled_features
    Feature.active
           .joins(:site_features)
           .where(site_features: { site_id: id, enabled: true })
           .ordered
  end

  def enabled_feature_ids
    site_features.enabled.pluck(:feature_id)
  end

  def feature_keys
    enabled_features.pluck(:key)
  end

  def feature_enabled?(feature)
    feature = Feature.resolve(feature)
    return false if feature.blank? || !feature.active?

    site_features.enabled.exists?(feature_id: feature.id)
  end

  # Replaces the site's entitlement set with the supplied feature ids. Removing
  # an entitlement also clears any user overrides that depended on it.
  def sync_features!(feature_ids, actor: nil)
    ids = Feature.active.where(id: Array(feature_ids).reject(&:blank?)).pluck(:id)

    transaction do
      site_features.where.not(feature_id: ids).find_each(&:destroy!)
      ids.each do |feature_id|
        site_feature = site_features.find_or_initialize_by(feature_id: feature_id)
        site_feature.enabled = true
        site_feature.enabled_by = actor
        site_feature.save!
      end
      user_features.where.not(feature_id: ids).find_each(&:destroy!)
    end

    ids
  end

  def to_s
    display_name
  end

  private

  def prevent_destroy_with_residents
    return unless user_sites.exists?

    errors.add(:base, "Cannot delete a site while resident associations exist.")
    throw :abort
  end

  def assign_code
    self.code = "SITE-#{SecureRandom.alphanumeric(5).upcase}"
    self.code = "SITE-#{SecureRandom.alphanumeric(5).upcase}" while self.class.exists?(code: code)
  end
end
