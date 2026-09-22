class Permission < ApplicationRecord
  belongs_to :role

  normalizes :resource, :action, with: ->(value) { value.to_s.strip.downcase }

  validates :resource, :action, presence: true
  validates :action, uniqueness: { scope: [ :role_id, :resource ] }
end
