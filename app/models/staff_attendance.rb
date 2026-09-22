class StaffAttendance < ApplicationRecord
  belongs_to :staff

  validates :punched_in_at, presence: true

  scope :open, -> { where(punched_out_at: nil) }
  scope :recent, -> { order(punched_in_at: :desc).limit(20) }

  def duration
    return nil if punched_out_at.blank?

    (punched_out_at - punched_in_at).round
  end

  def punch_out!(at: Time.current, ip: nil)
    update!(punched_out_at: at, ip_address: ip)
  end
end
