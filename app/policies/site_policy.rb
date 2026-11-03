class SitePolicy < ApplicationPolicy
  # Creating or removing a site is a platform-level action; only a super admin
  # may do it, otherwise the new site would immediately be outside the
  # creator's own site scope.
  def create?  = user&.super_admin? && permission?(:create)
  def destroy? = user&.super_admin? && permission?(:destroy)

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all unless site_restricted?

      scope.where(id: user.accessible_site_ids)
    end
  end
end
