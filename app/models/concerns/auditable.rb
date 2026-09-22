module Auditable
  extend ActiveSupport::Concern

  included do
    after_create_commit { record_audit("create") }
    after_update_commit { record_audit("update") }
    after_destroy_commit { record_audit("destroy") }
  end

  private

  def record_audit(action)
    actor = Current.user
    return if actor.nil?
    return if action == "update" && (previous_changes.keys - %w[updated_at last_login_at last_login_ip sign_in_count current_sign_in_at current_sign_in_ip last_sign_in_at last_sign_in_ip]).empty?

    AuditLog.create!(
      actor: actor,
      action: action,
      resource_type: self.class.name,
      resource_id: id,
      details: action == "update" ? previous_changes.except("updated_at") : {},
      ip_address: Current.request_ip,
      user_agent: Current.user_agent
    )
  end
end
