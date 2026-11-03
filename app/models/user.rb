class User < ApplicationRecord
  include Auditable

  MAX_FAILED_ATTEMPTS = 5
  LOCKOUT_DURATION = 30.minutes

  PROFILE_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  PROFILE_IMAGE_MAX_BYTES = 5.megabytes
  REGISTRATION_STATUSES = %w[pending approved rejected].freeze

  has_secure_password
  has_one_attached :profile_image

  belongs_to :role, optional: true
  belongs_to :department, optional: true
  belongs_to :reviewed_by, class_name: "User", foreign_key: :reviewed_by_id, optional: true
  belongs_to :current_site, class_name: "Site", foreign_key: :current_site_id, optional: true
  belongs_to :building, optional: true
  belongs_to :floor, optional: true
  belongs_to :unit, optional: true

  has_many :user_sites, dependent: :destroy, inverse_of: :user
  has_many :sites, through: :user_sites
  has_one :primary_user_site, -> { where(is_primary: true) }, class_name: "UserSite", inverse_of: :user

  has_many :user_features, dependent: :destroy, inverse_of: :user
  has_many :feature_overrides, through: :user_features, source: :feature

  has_many :created_visitors, class_name: "Visitor", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_staffs, class_name: "Staff", foreign_key: :created_by_id, dependent: :nullify

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :mobile, with: ->(mobile) { mobile.to_s.gsub(/\D/, "") }

  before_validation :sync_residence_from_unit
  after_create :ensure_primary_residence

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :firstname, :lastname, presence: true
  validates :password, length: { minimum: 12 }, allow_nil: true
  validates :mobile, length: { minimum: 10, maximum: 15 }, allow_blank: true
  validates :registration_status, inclusion: { in: REGISTRATION_STATUSES }
  validate :acceptable_profile_image
  validate :pending_registration_cannot_be_activated, on: :update

  scope :active, -> { where(active: true) }
  scope :pending_registration, -> { where(registration_status: "pending") }
  scope :with_role, -> { includes(:role) }
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip}%"
    where("firstname ILIKE :q OR lastname ILIKE :q OR email ILIKE :q OR mobile ILIKE :q", q: term)
  }

  # Hosts available for a unit: residents explicitly linked through user_sites
  # plus users whose primary unit is the selected unit.
  def self.hosts_for_unit(unit_id)
    active.where(
      "users.unit_id = :unit_id OR users.id IN (SELECT user_id FROM user_sites WHERE unit_id = :unit_id)",
      unit_id: unit_id
    ).includes(:role).order(:firstname, :lastname)
  end

  def full_name
    [ firstname, lastname ].compact_blank.join(" ")
  end

  def residence_label
    [ current_site&.name, building&.name, floor&.name, unit&.name ].compact.join(" / ")
  end

  alias site_label residence_label

  # Features are inherited from the user's current site. A user-level override
  # can grant or revoke an entitlement, but grants remain constrained to
  # features the site already exposes.
  def effective_features(site = current_site)
    site = Site.find_by(id: site) if site.is_a?(Integer)
    return Feature.none if site.blank?

    base_ids = site.enabled_features.pluck(:id)
    overrides = user_features.where(site_id: site.id).pluck(:feature_id, :enabled)
    granted_ids = overrides.select { |_feature_id, enabled| enabled }.map(&:first)
    revoked_ids = overrides.reject { |_feature_id, enabled| enabled }.map(&:first)

    Feature.active.where(id: (base_ids | granted_ids) - revoked_ids).ordered
  end

  def feature_keys(site = current_site)
    effective_features(site).pluck(:key)
  end

  def feature_enabled?(feature, site = current_site)
    feature = Feature.resolve(feature)
    return false if feature.blank?

    effective_features(site).exists?(id: feature.id)
  end

  def feature_override_state(feature, site = current_site)
    feature = Feature.resolve(feature)
    site = Site.find_by(id: site) if site.is_a?(Integer)
    return "inherit" if feature.blank? || site.blank?

    override = user_features.find_by(site_id: site.id, feature_id: feature.id)
    return "inherit" if override.blank?

    override.enabled? ? "granted" : "revoked"
  end

  # Overrides accept "granted", "revoked" or "inherit" per feature id.
  # Unknown features and features that are not enabled at the site are ignored.
  def sync_feature_overrides!(site, overrides, actor: nil)
    site = Site.find_by(id: site) if site.is_a?(Integer)
    raise ArgumentError, "A site is required" if site.blank?

    allowed_features = site.enabled_features.index_by(&:id)

    transaction do
      (overrides || {}).each do |feature_id, state|
        feature = allowed_features[feature_id.to_i]
        next if feature.blank?

        normalized = normalize_override_state(state)
        if normalized == "inherit"
          user_features.where(site_id: site.id, feature_id: feature.id).destroy_all
          next
        end

        override = user_features.find_or_initialize_by(site_id: site.id, feature_id: feature.id)
        override.enabled = normalized == "granted"
        override.granted_by = actor
        override.save!
      end

      user_features.where(site_id: site.id)
                   .where.not(feature_id: allowed_features.keys)
                   .find_each(&:destroy!)
    end
  end

  def role_key
    role&.key
  end

  def role_label
    role&.name || "Unassigned"
  end

  def pending_registration?
    registration_status == "pending"
  end

  def approved_registration?
    registration_status == "approved"
  end

  def rejected_registration?
    registration_status == "rejected"
  end

  # Self-registered employees stay inactive until an administrator approves
  # them. Approval assigns the default staff role when no role was set, so the
  # new employee can use the modules their role allows without an extra step.
  def approve_registration!(reviewer, note: nil)
    assign_attributes(
      registration_status: "approved",
      active: true,
      is_admin_approved: true,
      user_status: true,
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      registration_note: note.presence
    )
    self.role ||= Role.find_by(key: "staff")
    save!
  end

  def reject_registration!(reviewer, note: nil)
    assign_attributes(
      registration_status: "rejected",
      active: false,
      is_admin_approved: false,
      user_status: false,
      reviewed_by: reviewer,
      reviewed_at: Time.current,
      registration_note: note.presence
    )
    save!
  end

  def super_admin?
    role_key == "super_admin"
  end

  def admin?
    role_key == "admin"
  end

  def gate_security?
    role_key == "gate_security"
  end

  def security?
    %w[security gate_security].include?(role_key)
  end

  def can?(resource, action)
    super_admin? || role&.can?(resource, action)
  end

  def permission_keys
    if super_admin?
      Role::RESOURCES.flat_map do |resource|
        resource[:actions].map { |action| "#{resource[:key]}:#{action}" }
      end
    else
      role&.permissions&.pluck(:resource, :action)&.map { |resource, action| "#{resource}:#{action}" } || []
    end
  end

  def locked_out?
    locked_at.present? && locked_at > LOCKOUT_DURATION.ago
  end

  def locked_forever?
    locked_at.present? && !locked_out?
  end

  def register_failed_login!
    update_columns(failed_attempts: failed_attempts + 1)
    if failed_attempts >= MAX_FAILED_ATTEMPTS
      update_columns(locked_at: Time.current, lock_token: SecureRandom.urlsafe_base64(24))
    end
  end

  def unlock!
    update_columns(locked_at: nil, failed_attempts: 0, lock_token: nil)
  end

  def record_login!(request)
    update_columns(
      sign_in_count: sign_in_count + 1,
      current_sign_in_at: Time.current,
      last_sign_in_at: current_sign_in_at,
      current_sign_in_ip: request.remote_ip,
      last_sign_in_ip: current_sign_in_ip,
      last_login_at: Time.current,
      last_login_ip: request.remote_ip,
      failed_attempts: 0,
      locked_at: nil,
      lock_token: nil
    )
  end

  def generate_otp!
    raw_otp = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    update!(otp_digest: self.class.digest(raw_otp), otp_generated_at: Time.current)
    raw_otp
  end

  def verify_otp(input_otp)
    return false if otp_digest.blank? || otp_generated_at.blank? || otp_generated_at < 10.minutes.ago
    return false unless ActiveSupport::SecurityUtils.secure_compare(otp_digest, self.class.digest(input_otp.to_s))

    update!(otp_digest: nil, otp_generated_at: nil)
    true
  end

  def self.digest(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("otp-digest"), value.to_s)
  end

  private

  def acceptable_profile_image
    return unless profile_image.attached?

    unless PROFILE_IMAGE_TYPES.include?(profile_image.blob.content_type)
      errors.add(:profile_image, "must be a JPEG, PNG or WebP image")
    end

    return unless profile_image.blob.byte_size > PROFILE_IMAGE_MAX_BYTES

    errors.add(:profile_image, "must be smaller than 5 MB")
  end

  def pending_registration_cannot_be_activated
    return unless pending_registration? && active? && will_save_change_to_active?

    errors.add(:active, "cannot be enabled until the employee registration is approved")
  end

  def normalize_override_state(state)
    case state.to_s
    when "granted", "grant", "true", "1" then "granted"
    when "revoked", "revoke", "false", "0" then "revoked"
    else "inherit"
    end
  end

  def sync_residence_from_unit
    return if unit_id.blank?

    unit_record = Unit.find_by(id: unit_id)
    return if unit_record.blank?

    self.building_id = unit_record.building_id
    self.floor_id = unit_record.floor_id
    self.current_site_id = unit_record.site_id
  end

  def ensure_primary_residence
    return if unit_id.blank? || user_sites.exists?

    unit_record = Unit.find_by(id: unit_id)
    return if unit_record.blank?

    user_sites.create!(
      site: unit_record.site,
      building: unit_record.building,
      floor: unit_record.floor,
      unit: unit_record,
      ownership: "owner",
      is_primary: true,
      lives_here: true,
      is_approved: true
    )
  end
end
