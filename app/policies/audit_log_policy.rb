class AuditLogPolicy < ApplicationPolicy
  def export? = permission?(:export)
end
