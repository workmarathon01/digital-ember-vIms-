class UserPolicy < ApplicationPolicy
  def destroy? = permission?(:deactivate)

  def lock?
    permission?(:lock)
  end

  def unlock?
    permission?(:lock)
  end

  def show?
    super || record == user
  end

  def update?
    super || record == user
  end

  def edit?
    update?
  end
end
