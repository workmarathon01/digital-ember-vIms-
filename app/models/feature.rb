class Feature < ApplicationRecord
  include Auditable

  CATEGORIES = %w[general operations security resident reporting platform].freeze

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
