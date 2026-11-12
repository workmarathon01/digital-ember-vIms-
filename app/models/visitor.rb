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
  has_many :visitor_movements, dependent: :destroy

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

  # Compact public pass token: "<base36 id>-<11 char HMAC>". Short enough to
  # keep SMS messages and QR codes small, still unguessable (64-bit signature).
  COMPACT_TOKEN_PATTERN = /\A([0-9a-z]{1,10})-([A-Za-z0-9_-]{11})\z/
  COMPACT_SIGNATURE_BYTES = 8

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

      "#{visitor.id.to_s(36)}-#{compact_qr_signature(visitor)}"
    end

    def compact_qr_signature(visitor)
      raw = OpenSSL::HMAC.digest(
        "SHA256",
        Rails.application.key_generator.generate_key("visitor-pass-compact"),
        "visitor-pass:#{visitor.id}:#{visitor.pass_code}"
      )
      Base64.urlsafe_encode64(raw[0, COMPACT_SIGNATURE_BYTES], padding: false)
    end

    def verify_qr_token(value)
      token = value.to_s.strip
      return if token.blank?

      compact = verify_compact_qr_token(token)
      return compact if compact

      verify_legacy_qr_token(token)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    # A compact token only stores the visitor id; the signature proves the
    # token was issued for that visitor's current pass code.
    def verify_compact_qr_token(token)
      match = COMPACT_TOKEN_PATTERN.match(token)
      return unless match

      visitor = active.find_by(id: match[1].to_i(36))
      return if visitor.blank?
      return unless ActiveSupport::SecurityUtils.secure_compare(
        compact_qr_signature(visitor),
        match[2]
      )

      visitor
    end

    # Links sent before the compact token existed must keep working, so the
    # legacy MessageVerifier format is still accepted.
    def verify_legacy_qr_token(token)
      payload = qr_verifier.verified(token, purpose: "visitor-pass")
      return if payload.blank?

      visitor = active.find_by(id: payload["visitor_id"])
      return if visitor.blank?
      return if payload["pass_code"].present? && visitor.pass_code != payload["pass_code"]

      visitor
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

    # Base URL of the public Next.js app. Pass links are absolute so they can be
    # embedded in SMS or email and opened from any device.
    def public_pass_base_url
      base = ENV["VISITOR_PASS_BASE_URL"].presence || "https://amplify-automation.com"
      base.to_s.chomp("/")
    end

    # Only a signed token may be used to open the public pass page. Bare pass
    # codes remain useful at the gate but are too easy to guess for a public URL.
    def find_by_public_token(value)
      verify_qr_token(value)
    end
  end

  before_validation :sync_location_from_unit
  before_validation :set_default_pass_window, on: :create
  before_validation :set_default_status, on: :create
  before_validation :reuse_previous_profile_image, on: :create
  before_create :generate_qr_token_digest
  before_create :assign_pass_code
  after_create_commit :enqueue_pass_notification

  def checked_in?
    visitor_in_out == "IN"
  end

  # Absolute, shareable link to the public visitor pass page.
  def public_pass_url
    token = qr_token
    return if token.blank?

    "#{self.class.public_pass_base_url}/access/?t=#{ERB::Util.url_encode(token)}"
  end

  alias pass_url public_pass_url

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

  # Kept as convenience wrappers for callers that only need the state side
  # effect. The actual history is written by VisitorGate.
  def mark_checked_in!(ip: nil, occurred_at: Time.current, source: "staff", recorded_by: nil)
    VisitorGate.check_in(self, ip: ip, occurred_at: occurred_at, source: source, recorded_by: recorded_by)
  end

  def mark_checked_out!(ip: nil, occurred_at: Time.current, source: "staff", recorded_by: nil)
    VisitorGate.check_out(self, ip: ip, occurred_at: occurred_at, source: source, recorded_by: recorded_by)
  end

  # Newest-first list of paired entry/exit events. The open stay (if any) is
  # the first record with `ongoing?` true.
  def visit_history(limit: nil)
    VisitorStay.history_for(self, limit: limit)
  end

  def current_stay
    visit_history.find(&:ongoing?)
  end

  def last_movement_at
    visitor_movements.maximum(:occurred_at)
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

  def set_default_status
    self.status = true if status.nil?
  end

  def enqueue_pass_notification
    return unless status? && contact_no.present?

    VisitorPassNotificationJob.perform_later(id)
  rescue StandardError => e
    Rails.logger.error(
      "[VisitorPassNotification] Could not enqueue for visitor #{id}: #{e.message}"
    )
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
