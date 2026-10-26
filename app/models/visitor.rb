class Visitor < ApplicationRecord
  include Auditable
  attr_reader :raw_qr_token

  PROFILE_IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze
  PROFILE_IMAGE_MAX_BYTES = 5.megabytes

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :site, optional: true
  belongs_to :building, optional: true
  belongs_to :floor, optional: true
  belongs_to :unit, optional: true
  belongs_to :vhost, class_name: "User", optional: true

  has_one_attached :profile_image

  normalizes :contact_no, with: ->(contact_no) { contact_no.to_s.gsub(/\D/, "") }

  validates :name, :contact_no, presence: true
  validates :contact_no, length: { minimum: 10, maximum: 15 }, allow_blank: true
  validate :acceptable_profile_image
  validate :host_belongs_to_unit

  scope :active, -> { where(is_deleted: false) }
  scope :checked_in, -> { where(visitor_in_out: "IN") }
  scope :expiring, -> { where("start_pass <= ? AND end_pass >= ?", Time.current, Time.current) }
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip}%"
    where("name ILIKE :q OR contact_no ILIKE :q OR purpose ILIKE :q OR pass_code ILIKE :q OR vehicle_number ILIKE :q", q: term)
  }

  class << self
    def normalize_contact_no(value)
      value.to_s.gsub(/\D/, "")
    end

    def latest_for_contact(contact_no)
      normalized = normalize_contact_no(contact_no)
      return if normalized.blank?

      active.where(contact_no: normalized).order(created_at: :desc).first
    end

    def qr_verifier
      @qr_verifier ||= Rails.application.message_verifier("visitor-pass")
    end

    def signed_qr_token(visitor)
      return if visitor.id.blank? || visitor.pass_code.blank?

      qr_verifier.generate(
        { "visitor_id" => visitor.id, "pass_code" => visitor.pass_code },
        purpose: "visitor-pass"
      )
    end

    def verify_qr_token(value)
      payload = qr_verifier.verified(value, purpose: "visitor-pass")
      return if payload.blank?

      visitor = active.find_by(id: payload["visitor_id"])
      return if visitor.blank?
      return if payload["pass_code"].present? && visitor.pass_code != payload["pass_code"]

      visitor
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def extract_scan_code(value)
      code = value.to_s.strip
      return if code.blank?

      if code.match?(%r{\Ahttps?://}i)
        uri = URI.parse(code)
        query = Rack::Utils.parse_query(uri.query)
        code = query["t"].presence || query["token"].presence || code
      end

      code
    rescue URI::InvalidURIError
      value.to_s.strip
    end

    def find_by_scan_code(value)
      code = extract_scan_code(value)
      return if code.blank?

      active.find_by(pass_code: code) ||
        active.find_by(pass_code: code.upcase) ||
        verify_qr_token(code) ||
        active.find_by(qr_token_digest: token_digest(code))
    end

    def token_digest(value)
      OpenSSL::HMAC.hexdigest(
        "SHA256",
        Rails.application.key_generator.generate_key("visitor-token-digest"),
        value.to_s
      )
    end
  end

  before_validation :sync_location_from_unit
  before_validation :set_default_pass_window, on: :create
  before_validation :reuse_previous_profile_image, on: :create
  before_create :generate_qr_token_digest
  before_create :assign_pass_code

  def checked_in?
    visitor_in_out == "IN"
  end

  def location_label
    unit&.location_label || [ site&.display_name, building&.name, floor&.name ].compact.join(" / ")
  end

  def host_name
    vhost&.full_name
  end

  def qr_token
    self.class.signed_qr_token(self) || raw_qr_token
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

  def acceptable_profile_image
    return unless profile_image.attached?

    unless PROFILE_IMAGE_TYPES.include?(profile_image.blob.content_type)
      errors.add(:profile_image, "must be a JPEG, PNG or WebP image")
    end

    return unless profile_image.blob.byte_size > PROFILE_IMAGE_MAX_BYTES

    errors.add(:profile_image, "must be smaller than 5 MB")
  end

  def host_belongs_to_unit
    return if vhost_id.blank? || unit_id.blank?
    return if User.hosts_for_unit(unit_id).exists?(id: vhost_id)

    errors.add(:vhost_id, "must be linked to the selected unit")
  end

  # Returning visitors get a new pass record. If they do not upload a fresh
  # photo, carry the last known photo forward so every pass has a profile image.
  def reuse_previous_profile_image
    return if profile_image.attached? || contact_no.blank?

    previous = self.class.latest_for_contact(contact_no)
    return unless previous&.profile_image&.attached?

    profile_image.attach(
      io: StringIO.new(previous.profile_image.download),
      filename: previous.profile_image.filename.to_s,
      content_type: previous.profile_image.content_type
    )
  end

  def sync_location_from_unit
    return if unit_id.blank?

    unit_record = Unit.find_by(id: unit_id)
    return if unit_record.blank?

    self.site_id = unit_record.site_id
    self.building_id = unit_record.building_id
    self.floor_id = unit_record.floor_id
  end

  def set_default_pass_window
    self.start_pass ||= Time.current
    self.end_pass ||= 1.day.from_now
  end

  def assign_pass_code
    self.pass_code ||= "PASS-#{SecureRandom.alphanumeric(8).upcase}"
  end

  def generate_qr_token_digest
    @raw_qr_token = SecureRandom.urlsafe_base64(32)
    self.qr_token_digest = digest(@raw_qr_token)
    self.qr_generated_at = Time.current
  end

  def digest(value)
    self.class.token_digest(value)
  end
end
