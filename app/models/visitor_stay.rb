# A read-only projection of two visitor movements: an inbound scan and the
# outbound scan that closed it. Stays are never persisted, so the movement log
# remains the single source of truth.
class VisitorStay
  attr_reader :entry_event, :exit_event

  class << self
    def history_for(visitor, limit: nil)
      stays = []
      open_entry = nil

      visitor.visitor_movements.chronological.each do |movement|
        if movement.inbound?
          stays << new(open_entry) if open_entry
          open_entry = movement
        elsif open_entry
          stays << new(open_entry, movement)
          open_entry = nil
        end
      end

      stays << new(open_entry) if open_entry
      stays.reverse!
      limit ? stays.first(limit) : stays
    end
  end

  def initialize(entry_event, exit_event = nil)
    @entry_event = entry_event
    @exit_event = exit_event
  end

  def checked_in_at
    entry_event.occurred_at
  end

  def checked_out_at
    exit_event&.occurred_at
  end

  def ongoing?
    exit_event.nil?
  end

  def entry_source
    entry_event.source
  end

  def duration_seconds
    return if checked_out_at.blank?

    (checked_out_at - checked_in_at).to_i
  end

  def duration_in_words
    if ongoing?
      elapsed = ActiveSupport::Duration.build((Time.current - checked_in_at).to_i).inspect
      "#{elapsed} so far"
    else
      ActiveSupport::Duration.build(duration_seconds).inspect
    end
  end
end
