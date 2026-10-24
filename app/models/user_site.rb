class UserSite < ApplicationRecord
  include Auditable

  OWNERSHIPS = %w[owner tenant family member staff other].freeze

  belongs_to :user
  belongs_to :site
  belongs_to :building, optional: true
  belongs_to :floor, optional: true
  belongs_to :unit, optional: true

  normalizes :ownership, with: ->(ownership) { ownership.to_s.strip.downcase.presence || "owner" }

  before_validation :derive_location
  before_save :demote_other_primaries, if: :is_primary?
  after_save :sync_user_location
  after_destroy :replace_primary_after_destroy

  validates :ownership, inclusion: { in: OWNERSHIPS }
  validates :unit_id, uniqueness: { scope: :user_id, message: "is already associated with this resident" }, allow_nil: true
  validates :move_out_date, comparison: { greater_than_or_equal_to: :move_in_date }, allow_nil: true
  validate :unit_belongs_to_location

  scope :primary, -> { where(is_primary: true) }
  scope :approved, -> { where(is_approved: true) }
  scope :residents, -> { where.not(unit_id: nil) }
  scope :recent_first, -> { order(is_primary: :desc, created_at: :desc) }

  def primary?
    is_primary?
  end

  def location_label
    [ site&.name, building&.name, floor&.name, unit&.name ].compact.join(" / ")
  end

  def to_s
    "#{user&.full_name} · #{location_label}"
  end

  private

  def derive_location
    if unit.present?
      self.site_id = unit.site_id
      self.building_id = unit.building_id
      self.floor_id = unit.floor_id
    elsif floor.present?
      self.building_id = floor.building_id
      self.site_id = floor.site_id
      self.unit_id = nil
    elsif building.present?
      self.site_id = building.site_id
      self.floor_id = nil
      self.unit_id = nil
    end
  end

  def demote_other_primaries
    self.class.where(user_id: user_id).where.not(id: id).update_all(is_primary: false, updated_at: Time.current)
  end

  def unit_belongs_to_location
    return if unit.blank?

    if site_id.present? && unit.site_id != site_id
      errors.add(:site, "does not match the selected unit")
    end
    if building_id.present? && unit.building_id != building_id
      errors.add(:building, "does not match the selected unit")
    end
    if floor_id.present? && unit.floor_id != floor_id
      errors.add(:floor, "does not match the selected unit")
    end
  end

  def sync_user_location
    self.class.sync_user_location(user_id)
  end

  def replace_primary_after_destroy
    return unless is_primary?

    replacement = self.class.where(user_id: user_id).order(created_at: :desc).first
    replacement&.update_columns(is_primary: true, updated_at: Time.current)
    self.class.sync_user_location(user_id)
  end

  def self.sync_user_location(user_id)
    user = User.find_by(id: user_id)
    return if user.blank?

    primary = where(user_id: user_id, is_primary: true).order(updated_at: :desc).first

    if primary
      user.update_columns(
        current_site_id: primary.site_id,
        building_id: primary.building_id,
        floor_id: primary.floor_id,
        unit_id: primary.unit_id
      )
    elsif user.user_sites.none?
      user.update_columns(current_site_id: nil, building_id: nil, floor_id: nil, unit_id: nil)
    end
  end
end
