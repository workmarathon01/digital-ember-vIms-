class AuditLog < ApplicationRecord
  belongs_to :actor, polymorphic: true

  validates :action, presence: true

  scope :newest_first, -> { order(created_at: :desc) }
  scope :for_resource, ->(resource) { where(resource_type: resource.class.name, resource_id: resource.id) }

  def resource
    return nil if resource_type.blank? || resource_id.blank?

    resource_type.constantize.find_by(id: resource_id)
  rescue NameError
    nil
  end

  def actor_name
    actor.respond_to?(:full_name) ? actor.full_name : actor.to_s
  end

  def resource_name
    return "—" if resource_type.blank?

    label = resource_type.demodulize.titleize
    record = resource
    return label if record.blank?
    return "#{label} #{record.full_name}" if record.respond_to?(:full_name)

    "#{label} ##{record.id}"
  end
end
