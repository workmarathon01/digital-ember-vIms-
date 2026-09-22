class Staff < ApplicationRecord
  include Auditable

  belongs_to :created_by, class_name: "User", optional: true
  has_many :attendances, class_name: "StaffAttendance", dependent: :destroy

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :mobile_no, with: ->(mobile_no) { mobile_no.to_s.gsub(/\D/, "") }

  validates :firstname, :lastname, :mobile_no, presence: true
  validates :mobile_no, uniqueness: { scope: :site_id }, length: { minimum: 10, maximum: 15 }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :status_type, inclusion: { in: %w[Pending Approved Rejected Suspended] }
  validate :working_schedule_shape

  before_validation :set_defaults

  scope :approved, -> { where(status_type: "Approved") }
  scope :active, -> { where(status: true) }
  scope :on_site, -> { where(staff_in_out: "IN") }
  scope :search, lambda { |q|
    term = "%#{q.to_s.strip}%"
    where("firstname ILIKE :q OR lastname ILIKE :q OR email ILIKE :q OR mobile_no ILIKE :q OR staff_id ILIKE :q OR work_type ILIKE :q", q: term)
  }

  def full_name
    [ firstname, lastname ].compact_blank.join(" ")
  end

  def approve!
    update!(status_type: "Approved", status: true)
  end

  def suspend!
    update!(status_type: "Suspended", status: false)
  end

  def open_attendance
    attendances.open.first
  end

  def punch_in!(ip: nil)
    attendances.create!(punched_in_at: Time.current, ip_address: ip)
  end

  def punch_out!(ip: nil)
    open_attendance&.punch_out!(at: Time.current, ip: ip)
  end

  def filtered_working_schedule
    return {} if working_schedule.blank?

    working_schedule.transform_values(&:symbolize_keys)
                    .select { |_, ts| ts[:selected] == true || (ts[:selected].to_s == "true") }
  end

  private

  def set_defaults
    self.status_type ||= "Pending"
    self.status = true if status.nil?
    self.staff_id ||= next_staff_id
    self.qr_token_digest ||= token_digest(SecureRandom.urlsafe_base64(32))
    self.qr_generated_at ||= Time.current
    self.working_schedule ||= default_working_schedule
  end

  def working_schedule_shape
    return if working_schedule.nil? || working_schedule.is_a?(Hash)

    errors.add(:working_schedule, "must be a hash of day schedules")
  end

  def default_working_schedule
    Date::DAYNAMES.index_with({ selected: false, start_time: nil, end_time: nil })
  end

  def next_staff_id
    loop do
      candidate = "STF#{SecureRandom.hex(3).upcase}"
      break candidate unless self.class.exists?(staff_id: candidate)
    end
  end

  def token_digest(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("staff-token-digest"), value.to_s)
  end
end
