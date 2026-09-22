class DashboardController < ApplicationController
  def show
    authorize :dashboard, :view?

    @users_count = policy_scope(User).count
    @visitors_count = policy_scope(Visitor).active.count
    @checked_in_visitors_count = policy_scope(Visitor).checked_in.count
    @staffs_count = policy_scope(Staff).count
    @pending_staffs_count = policy_scope(Staff).where(status_type: "Pending").count
    @attendance_open = current_user.can?(:staffs, :read) ? StaffAttendance.open.count : 0
    @recent_activity =
      if current_user.can?(:audit_logs, :read)
        AuditLog.newest_first.limit(8).includes(:actor)
      else
        []
      end
  end
end
