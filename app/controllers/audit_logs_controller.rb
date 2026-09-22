class AuditLogsController < ApplicationController
  def index
    authorize AuditLog
    @logs = policy_scope(AuditLog).newest_first
    @logs = @logs.where(actor_type: "User", actor_id: params[:actor_id]) if params[:actor_id].present?
    @logs = @logs.where(resource_type: params[:resource_type]) if params[:resource_type].present?
    @logs = @logs.where(action: params[:action]) if params[:action].present?
    @pagy, @logs = pagy(@logs.includes(:actor), items: 50)
  end
end
