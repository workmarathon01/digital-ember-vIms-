class DepartmentPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all unless site_restricted?

      ids = user.accessible_site_ids
      # Keep legacy departments that were created before departments were
      # site-specific (site_id is nil) visible to every site.
      scope.where(site_id: ids).or(scope.where(site_id: nil))
    end
  end
end
