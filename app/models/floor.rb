class Floor < ApplicationRecord
  include Auditable

  before_destroy :prevent_destroy_with_residents

  belongs_to :site
  belongs_to :building
  has_many :units, dependent: :destroy, inverse_of: :floor
  has_many :user_sites, dependent: :restrict_with_error, inverse_of: :floor
  has_many :users, through: :user_sites

  normalizes :name, with: ->(name) { name.to_s.strip.squish }

  before_validation :sync_site_from_building
  before_validation :assign_level

  validates :name, presence: true, length: { maximum: 120 },
                   uniqueness: { scope: :building_id, case_sensitive: false }

  scope :ordered, -> { order(:level, :name) }
  scope :search, lambda { |query|
    term = "%#{query.to_s.strip}%"
    where("floors.name ILIKE :term", term: term)
  }

  def display_name
    "#{name} · #{building.name}"
  end

  def location_label
    [ site.name, building.name, name ].compact.join(" / ")
  end

  def to_s
    display_name
  end

  private

  def prevent_destroy_with_residents
    return unless user_sites.exists?

    errors.add(:base, "Cannot delete a floor while resident associations exist.")
    throw :abort
  end

  def sync_site_from_building
    self.site_id = building.site_id if building.present?
  end

  def assign_level
    return if level.present? || name.blank?

    match = name.match(/-?\d+/)
    self.level = match ? match[0].to_i : 0
  end
end
