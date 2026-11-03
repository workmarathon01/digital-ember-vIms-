class Role < ApplicationRecord
  SYSTEM_KEYS = %w[super_admin admin security gate_security staff resident].freeze

  RESOURCES = [
    { key: "users", label: "Users", actions: %w[read create update deactivate lock assign_roles approve reject] },
    { key: "departments", label: "Departments", actions: %w[read create update destroy] },
    { key: "features", label: "Feature Catalog", actions: %w[read create update destroy] },
    { key: "site_features", label: "Site Feature Access", actions: %w[read update] },
    { key: "user_features", label: "User Feature Access", actions: %w[read update] },
    { key: "sites", label: "Sites", actions: %w[read create update destroy] },
    { key: "buildings", label: "Buildings", actions: %w[read create update destroy] },
    { key: "floors", label: "Floors", actions: %w[read create update destroy] },
    { key: "units", label: "Units", actions: %w[read create update destroy] },
    { key: "user_sites", label: "Resident Assignments", actions: %w[read create update destroy] },
    { key: "visitors", label: "Visitors", actions: %w[read create update destroy check_in check_out generate_otp export] },
    { key: "staffs", label: "Staff", actions: %w[read create update destroy approve suspend attendance export] },
    { key: "roles", label: "Roles", actions: %w[read create update destroy permissions] },
    { key: "audit_logs", label: "Activity Log", actions: %w[read export] }
  ].freeze

  ALL_ACTIONS = RESOURCES.flat_map { |r| r[:actions] }.uniq.freeze

  has_many :users, dependent: :nullify
  has_many :permissions, dependent: :destroy, inverse_of: :role

  accepts_nested_attributes_for :permissions, allow_destroy: true

  normalizes :key, with: ->(key) { key.to_s.strip.downcase.parameterize(separator: "_") }
  normalizes :name, with: ->(name) { name.to_s.strip.titleize }

  validates :name, :key, presence: true
  validates :key, uniqueness: { case_sensitive: false }, format: { with: /\A[a-z][a-z0-9_]*\z/ }
  validates :power_level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :key, inclusion: { in: SYSTEM_KEYS }, if: :is_system?

  scope :active, -> { where(active: true) }

  def super_admin?
    key == "super_admin"
  end

  def admin?
    key == "admin"
  end

  def gate_security?
    key == "gate_security"
  end

  def system?
    is_system? || SYSTEM_KEYS.include?(key)
  end

  def can?(resource, action)
    super_admin? || permissions.exists?(resource: resource.to_s, action: action.to_s)
  end

  def permission_for?(resource)
    granted = permissions.where(resource: resource[:key])
    if super_admin?
      resource[:actions]
    else
      granted.pluck(:action)
    end
  end
end
