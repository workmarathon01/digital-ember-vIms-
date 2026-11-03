class AuditLogPolicy < ApplicationPolicy
  def export? = permission?(:export)

  # Activity is site data too: a scoped user only sees events performed by
  # people attached to their sites.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all unless site_restricted?

      scope.where(actor_type: "User", actor_id: User.for_sites(user.accessible_site_ids).select(:id))
    end
  end
end
