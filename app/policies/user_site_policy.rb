class UserSitePolicy < ApplicationPolicy
  def make_primary? = permission?(:update)
end
