class DashboardController < ApplicationController
  def show
    authorize :dashboard, :view?

    @users_count = current_user.can?(:users, :read) ? policy_scope(User).count : 0
    @sites_count = current_user.can?(:sites, :read) ? policy_scope(Site).count : 0
    @units_count = current_user.can?(:units, :read) ? policy_scope(Unit).count : 0
    @visitors_count = current_user.can?(:visitors, :read) ? policy_scope(Visitor).active.count : 0
    @checked_in_visitors_count = current_user.can?(:visitors, :read) ? policy_scope(Visitor).checked_in.count : 0
    @staffs_count = current_user.can?(:staffs, :read) ? policy_scope(Staff).count : 0
    @pending_staffs_count = current_user.can?(:staffs, :read) ? policy_scope(Staff).where(status_type: "Pending").count : 0
    @attendance_open =
      if current_user.can?(:staffs, :read)
        StaffAttendance.open.joins(:staff).merge(policy_scope(Staff)).count
      else
        0
      end
    @recent_activity =
      if current_user.can?(:audit_logs, :read)
        policy_scope(AuditLog).newest_first.limit(8).includes(:actor)
      else
        []
      end
  end
end
