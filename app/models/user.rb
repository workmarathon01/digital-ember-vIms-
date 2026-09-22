class User < ApplicationRecord
  include Auditable

  MAX_FAILED_ATTEMPTS = 5
  LOCKOUT_DURATION = 30.minutes

  has_secure_password

  belongs_to :role, optional: true

  has_many :created_visitors, class_name: "Visitor", foreign_key: :created_by_id, dependent: :nullify
  has_many :created_staffs, class_name: "Staff", foreign_key: :created_by_id, dependent: :nullify

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :mobile, with: ->(mobile) { mobile.to_s.gsub(/\D/, "") }

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :firstname, :lastname, presence: true
  validates :password, length: { minimum: 8 }, allow_nil: true
  validates :mobile, length: { minimum: 10, maximum: 15 }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :with_role, -> { includes(:role) }
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip}%"
    where("firstname ILIKE :q OR lastname ILIKE :q OR email ILIKE :q OR mobile ILIKE :q", q: term)
  }

  def full_name
    [ firstname, lastname ].compact_blank.join(" ")
  end

  def role_key
    role&.key
  end

  def role_label
    role&.name || "Unassigned"
  end

  def super_admin?
    role_key == "admin"
  end

  def admin?
    super_admin?
  end

  def security?
    role_key == "security"
  end

  def can?(resource, action)
    super_admin? || role&.can?(resource, action)
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
end
