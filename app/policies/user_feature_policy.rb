class UserFeaturePolicy < ApplicationPolicy
  def show? = permission?(:read)
  def update? = permission?(:update)
end
