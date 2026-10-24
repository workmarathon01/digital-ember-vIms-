class Unit < ApplicationRecord
  include Auditable

  before_destroy :prevent_destroy_with_residents

  STATUSES = %w[active inactive maintenance].freeze

  belongs_to :site
  belongs_to :building
  belongs_to :floor
  has_many :user_sites, dependent: :restrict_with_error, inverse_of: :unit
  has_many :users, through: :user_sites
  has_many :staffs, dependent: :nullify
  has_many :visitors, dependent: :nullify

  normalizes :name, with: ->(name) { name.to_s.strip.squish }

  before_validation :sync_hierarchy
  before_validation :default_status

  validates :name, presence: true, length: { maximum: 120 },
                   uniqueness: { scope: :floor_id, case_sensitive: false }
  validates :status, inclusion: { in: STATUSES }
  validates :carpet_area, numericality: { greater_than: 0 }, allow_nil: true
  validate :floor_belongs_to_building

  scope :active, -> { where(status: "active") }
  scope :occupied, -> { where(id: UserSite.select(:unit_id)) }
  scope :vacant, -> { where.not(id: UserSite.select(:unit_id)) }
  scope :search, lambda { |query|
    term = "%#{query.to_s.strip}%"
    where("units.name ILIKE :term OR units.unit_type ILIKE :term", term: term)
  }

  def occupied?
    user_sites.exists?
  end

  def location_label
    [ site.name, building.name, floor.name, name ].compact.join(" / ")
  end

  def full_address
    [ name, floor.name, building.name, site.name ].compact.join(", ")
  end

  def to_s
    location_label
  end

  private

  def prevent_destroy_with_residents
    return unless user_sites.exists?

    errors.add(:base, "Cannot delete a unit while resident associations exist.")
    throw :abort
  end

  def sync_hierarchy
    return if floor.blank?

    self.building_id = floor.building_id
    self.site_id = floor.site_id
  end

  def default_status
    self.status = "active" if status.blank?
  end

  def floor_belongs_to_building
    return if floor.blank? || building.blank?

    return if floor.building_id == building_id

    errors.add(:floor, "does not belong to the selected building")
  end
end
