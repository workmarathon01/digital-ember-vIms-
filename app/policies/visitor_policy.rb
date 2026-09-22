class VisitorPolicy < ApplicationPolicy
  def check_in?     = permission?(:check_in)
  def check_out?    = permission?(:check_out)
  def generate_otp? = permission?(:generate_otp)
  def export?       = permission?(:export)
end
