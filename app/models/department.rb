class Department < ApplicationRecord
  include Auditable

  belongs_to :site, optional: true

  has_many :users, foreign_key: :department_id, dependent: :nullify, inverse_of: :department

  normalizes :name, with: ->(name) { name.to_s.strip.squish }
  normalizes :code, with: ->(code) { code.to_s.strip.upcase }

  before_validation :assign_code, if: -> { code.blank? }

  validates :name, presence: true, length: { maximum: 120 },
                   uniqueness: { case_sensitive: false, scope: :site_id }
  validates :code, presence: true, length: { maximum: 24 },
                   uniqueness: { case_sensitive: false, scope: :site_id },
                   format: { with: /\A[A-Z0-9][A-Z0-9_-]{1,23}\z/,
                             message: "may use letters, numbers, dashes and underscores" }
  validates :description, length: { maximum: 1000 }, allow_blank: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }
  scope :for_site, ->(site_id) { site_id.present? ? where(site_id: site_id) : all }
  scope :search, lambda { |query|
    term = "%#{query.to_s.strip}%"
    where("departments.name ILIKE :term OR departments.code ILIKE :term OR departments.description ILIKE :term",
          term: term)
  }

  def to_s
    name
  end

  private

  def assign_code
    base = name.to_s.parameterize(separator: "_").upcase.presence || "DEPT"
    base = base.first(19)
    base = "DEPT" if base.length < 2
    candidate = base
    candidate = "#{base}-#{SecureRandom.alphanumeric(4).upcase}" while self.class.where(site_id: site_id).exists?(code: candidate)
    self.code = candidate
  end
end
