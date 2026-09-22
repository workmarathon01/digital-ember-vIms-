class RolePolicy < ApplicationPolicy
  def permissions? = permission?(:permissions)

  def permitted_user_assignments?
    permission?(:permissions)
  end
end
