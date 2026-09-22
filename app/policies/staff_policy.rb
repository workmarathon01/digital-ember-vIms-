class StaffPolicy < ApplicationPolicy
  def approve?   = permission?(:approve)
  def suspend?   = permission?(:suspend)
  def punch_in?  = permission?(:attendance)
  def punch_out? = permission?(:attendance)
  def export?    = permission?(:export)
end
