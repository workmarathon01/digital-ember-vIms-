# Records visitor gate movements and keeps the visitor's cached in/out state
# in sync. All check-ins and check-outs should go through this service so the
# movement log and the visitors table cannot drift apart.
#
#   VisitorGate.check_in(visitor, source: "public", ip: request.remote_ip)
#   VisitorGate.check_out(visitor, recorded_by: current_user)
class VisitorGate
  Result = Struct.new(:movement, :error_code, :error_message, :duplicate, keyword_init: true) do
    def success?
      error_code.nil?
    end

    def duplicate?
      duplicate == true
    end
  end

  class << self
    def check_in(visitor, occurred_at: Time.current, source: "staff", recorded_by: nil, ip: nil)
      new(visitor, direction: "in", occurred_at: occurred_at, source: source,
          recorded_by: recorded_by, ip: ip).record
    end

    def check_out(visitor, occurred_at: Time.current, source: "staff", recorded_by: nil, ip: nil)
      new(visitor, direction: "out", occurred_at: occurred_at, source: source,
          recorded_by: recorded_by, ip: ip).record
    end
  end

  def initialize(visitor, direction:, occurred_at:, source:, recorded_by:, ip:)
    @visitor = visitor
    @direction = direction.to_s
    @occurred_at = normalize_time(occurred_at)
    @source = source.to_s.presence || "staff"
    @recorded_by = recorded_by
    @ip = ip
  end

  def record
    unless VisitorMovement::DIRECTIONS.include?(direction)
      return failure(:invalid_direction, "Direction must be in or out.")
    end

    unless VisitorMovement::SOURCES.include?(source)
      return failure(:invalid_source, "Unknown movement source.")
    end

    visitor.with_lock do
      ensure_legacy_entry!

      if direction == "in"
        next already_checked_in if open_entry.present?

        if latest_movement.present? && occurred_at < latest_movement.occurred_at
          next failure(:invalid_time, "Check-in cannot be earlier than the last movement.")
        end

        movement = create_movement!("in")
        sync_visitor!(movement)
        Result.new(movement: movement)
      else
        next not_checked_in if open_entry.blank?

        if occurred_at < open_entry.occurred_at
          next failure(:invalid_time, "Check-out cannot be earlier than check-in.")
        end

        movement = create_movement!("out")
        sync_visitor!(movement)
        Result.new(movement: movement)
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    failure(:invalid_movement, e.record.errors.full_messages.to_sentence)
  end

  private

  attr_reader :visitor, :direction, :occurred_at, :source, :recorded_by, :ip

  # Older visitor rows only carry `visitor_in_out`. If such a visitor is still
  # inside, give them an entry event before calculating their state.
  def ensure_legacy_entry!
    return if open_entry.present? || visitor.visitor_in_out != "IN"

    @open_entry = visitor.visitor_movements.create!(
      direction: "in",
      occurred_at: visitor.qr_checked_in_at || occurred_at,
      source: "system",
      recorded_by: recorded_by,
      ip_address: ip
    )
    @latest_movement = @open_entry
  end

  def latest_movement
    return @latest_movement if defined?(@latest_movement)

    @latest_movement = visitor.visitor_movements.recent_first.first
  end

  def open_entry
    return @open_entry if defined?(@open_entry)

    @open_entry = latest_movement&.inbound? ? latest_movement : nil
  end

  def create_movement!(movement_direction)
    visitor.visitor_movements.create!(
      direction: movement_direction,
      occurred_at: occurred_at,
      source: source,
      recorded_by: recorded_by,
      ip_address: ip
    )
  end

  # The visitors table keeps a small cache of the current state for the list
  # screens and existing API clients. The movement log stays authoritative.
  def sync_visitor!(movement)
    if movement.inbound?
      visitor.update!(
        visitor_in_out: "IN",
        qr_checked_in_at: movement.occurred_at,
        status: true,
        otp_attempts: 0
      )
    else
      visitor.update!(visitor_in_out: "OUT", status: false)
    end
  end

  def already_checked_in
    Result.new(
      movement: open_entry,
      duplicate: true,
      error_message: "Visitor is already checked in."
    )
  end

  def not_checked_in
    failure(:not_checked_in, "Visitor is not checked in.")
  end

  def failure(code, message)
    Result.new(error_code: code, error_message: message)
  end

  def normalize_time(value)
    return Time.current if value.blank?
    return value if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s) || Time.current
  rescue ArgumentError
    Time.current
  end
end
