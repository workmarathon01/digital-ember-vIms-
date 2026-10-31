class UserPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.super_admin?

      super_admins = Role.where(key: "super_admin").select(:id)
      scope.where(role_id: nil).or(scope.where.not(role_id: super_admins))
    end
  end

  def destroy? = !protected_record? && permission?(:deactivate)

  def lock?
    !protected_record? && permission?(:lock)
  end

  def unlock?
    !protected_record? && permission?(:lock)
  end

  def show?
    !protected_record? && (super || record == user)
  end

  def update?
    !protected_record? && (super || record == user)
  end

  def edit?
    update?
  end

  # Older admin roles were granted "update" but not the newer "approve" /
  # "reject" actions, so accept either permission. A registration can only be
  # reviewed while it is still pending.
  def approve?
    record.pending_registration? && (permission?(:approve) || permission?(:update))
  end

  def reject?
    record.pending_registration? && (permission?(:reject) || permission?(:update))
  end

  private

  # Only another super admin may view or change a super admin account.
  def protected_record?
    record.respond_to?(:super_admin?) && record.super_admin? && !user&.super_admin?
  end
end
