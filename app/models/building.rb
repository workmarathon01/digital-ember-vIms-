class Building < ApplicationRecord
  include Auditable

  before_destroy :prevent_destroy_with_residents

  belongs_to :site
  has_many :floors, dependent: :destroy, inverse_of: :building
  has_many :units, inverse_of: :building
  has_many :user_sites, dependent: :restrict_with_error, inverse_of: :building
  has_many :users, through: :user_sites

  normalizes :code, with: ->(code) { code.to_s.strip.upcase }
  normalizes :name, with: ->(name) { name.to_s.strip.squish }

  before_validation :assign_code, if: -> { code.blank? }

  validates :name, presence: true, length: { maximum: 120 },
                   uniqueness: { scope: :site_id, case_sensitive: false }
  validates :code, uniqueness: { scope: :site_id, case_sensitive: false }, allow_blank: true

  scope :search, lambda { |query|
    term = "%#{query.to_s.strip}%"
    where("buildings.name ILIKE :term OR buildings.code ILIKE :term", term: term)
  }

  def display_name
    "#{name} · #{site.name}"
  end

  def location_label
    [ site.name, name ].compact.join(" / ")
  end

  def to_s
    display_name
  end

  private

  def prevent_destroy_with_residents
    return unless user_sites.exists?

    errors.add(:base, "Cannot delete a building while resident associations exist.")
    throw :abort
  end

  def assign_code
    return if site.blank?

    base = name.to_s.parameterize(separator: "-").upcase.presence || "BLDG"
    candidate = "#{base}-#{SecureRandom.alphanumeric(4).upcase}"
    self.code = candidate
    self.code = "#{base}-#{SecureRandom.alphanumeric(4).upcase}" while self.class.exists?(site_id: site_id, code: code)
  end
end
