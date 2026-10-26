class Feature < ApplicationRecord
  include Auditable

  CATEGORIES = %w[general operations security resident reporting platform].freeze

  STANDARD_TEMPLATES = [
    { key: "visitor_management", name: "Visitor Management", category: "operations", icon: "clipboard-list",
      sort_order: 10, default_enabled: true,
      description: "Pre-registration, gate passes, OTP check-in and visitor history." },
    { key: "staff_management", name: "Staff Management", category: "operations", icon: "users",
      sort_order: 20, default_enabled: true,
      description: "Staff directory, approvals, shifts and attendance." },
    { key: "property_management", name: "Properties & Residents", category: "operations", icon: "building",
      sort_order: 30, default_enabled: true,
      description: "Site, building, floor and unit hierarchy with resident associations." },
    { key: "gate_passes", name: "Gate Passes & OTP", category: "security", icon: "key-round",
      sort_order: 40, default_enabled: true,
      description: "Pass-code and OTP verification for gate operations." },
    { key: "kiosk_mode", name: "Kiosk Check-in", category: "security", icon: "monitor-smartphone",
      sort_order: 50, default_enabled: true,
      description: "Self-service visitor check-in at a shared kiosk." },
    { key: "audit_trail", name: "Audit Trail", category: "platform", icon: "scroll-text",
      sort_order: 60, default_enabled: true,
      description: "Immutable activity history for security and compliance." },
    { key: "reports", name: "Reports & Analytics", category: "reporting", icon: "bar-chart",
      sort_order: 70, default_enabled: true,
      description: "Operational reporting and occupancy insights." },
    { key: "user_management", name: "Users & Roles", category: "platform", icon: "user-cog",
      sort_order: 80, default_enabled: true,
      description: "User accounts, role assignments and access control." }
  ].freeze

  before_destroy :prevent_destroy_when_assigned

  has_many :site_features, dependent: :destroy, inverse_of: :feature
  has_many :sites, through: :site_features
  has_many :user_features, dependent: :destroy, inverse_of: :feature

  normalizes :key, with: ->(key) { key.to_s.strip.downcase.parameterize(separator: "_") }
  normalizes :name, with: ->(name) { name.to_s.strip.squish }

  before_validation :assign_key, if: -> { key.blank? }

  validates :key, presence: true, uniqueness: { case_sensitive: false },
                  format: { with: /\A[a-z][a-z0-9_]*\z/, message: "may use lowercase letters, numbers and underscores" }
  validates :name, presence: true, length: { maximum: 120 }
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :sort_order, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :name) }
  scope :search, lambda { |query|
    term = "%#{query.to_s.strip}%"
    where("features.name ILIKE :term OR features.key ILIKE :term OR features.category ILIKE :term", term: term)
  }

  def self.resolve(value)
    case value
    when Feature then value
    when Integer then find_by(id: value)
    else find_by(key: value.to_s)
    end
  end

  def to_s
    name
  end

  private

  def assign_key
    self.key = name.to_s.parameterize(separator: "_")
  end

  def prevent_destroy_when_assigned
    return unless site_features.exists?

    errors.add(:base, "Disable this feature for every site before deleting it.")
    throw :abort
  end
end
