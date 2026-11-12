# Append-only gate history for a visitor.
#
# Unlike a paired check-in/check-out record, every scan is stored as its own
# immutable movement. The visitor's current state is the direction of the most
# recent movement; visit sessions are projected on demand by VisitorStay.
class VisitorMovement < ApplicationRecord
  DIRECTIONS = %w[in out].freeze
  SOURCES = %w[staff public api system].freeze

  belongs_to :visitor
  belongs_to :recorded_by, class_name: "User", optional: true

  validates :occurred_at, presence: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :source, inclusion: { in: SOURCES }

  scope :chronological, -> { order(:occurred_at, :id) }
  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }
  scope :inbound, -> { where(direction: "in") }
  scope :outbound, -> { where(direction: "out") }

  def inbound?
    direction == "in"
  end

  def outbound?
    direction == "out"
  end
end
