class Visitor < ApplicationRecord
  include Auditable

  belongs_to :created_by, class_name: "User", optional: true

  normalizes :contact_no, with: ->(contact_no) { contact_no.to_s.gsub(/\D/, "") }

  validates :name, :contact_no, presence: true
  validates :contact_no, length: { minimum: 10, maximum: 15 }, allow_blank: true

  scope :active, -> { where(is_deleted: false) }
  scope :checked_in, -> { where(visitor_in_out: "IN") }
  scope :expiring, -> { where("start_pass <= ? AND end_pass >= ?", Time.current, Time.current) }
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip}%"
    where("name ILIKE :q OR contact_no ILIKE :q OR purpose ILIKE :q OR pass_code ILIKE :q OR vehicle_number ILIKE :q", q: term)
  }

  before_validation :set_default_pass_window, on: :create
  before_create :generate_qr_token_digest
  before_create :assign_pass_code

  def checked_in?
    visitor_in_out == "IN"
  end

  def pass_active?
    status? && start_pass.present? && start_pass <= Time.current && (end_pass.nil? || end_pass >= Time.current)
  end

  def generate_otp!
    return false if otp_attempts.to_i >= 5

    raw_otp = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")
    update!(otp_digest: digest(raw_otp), otp_generated_at: Time.current)
    raw_otp
  end

  def verify_otp(input_otp)
    return false if otp_digest.blank? || otp_generated_at.blank? || otp_generated_at < 10.minutes.ago
    return false unless ActiveSupport::SecurityUtils.secure_compare(otp_digest, digest(input_otp.to_s))

    update!(otp_digest: nil, otp_generated_at: nil, verified: true)
    true
  end

  def mark_checked_in!(ip: nil)
    update!(visitor_in_out: "IN", qr_checked_in_at: Time.current, status: true, otp_attempts: 0)
  end

  def mark_checked_out!
    update!(visitor_in_out: "OUT", status: false)
  end

  private

  def set_default_pass_window
    self.start_pass ||= Time.current
    self.end_pass ||= 1.day.from_now
  end

  def assign_pass_code
    self.pass_code ||= "PASS-#{SecureRandom.alphanumeric(8).upcase}"
  end

  def generate_qr_token_digest
    raw_token = SecureRandom.urlsafe_base64(32)
    self.qr_token_digest = digest(raw_token)
    self.qr_generated_at = Time.current
  end

  def digest(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("visitor-token-digest"), value.to_s)
  end
end
