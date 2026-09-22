class VisitorsController < ApplicationController
  before_action :set_visitor, only: %i[show edit update destroy generate_otp check_in check_out]

  def index
    authorize Visitor
    @visitors = policy_scope(Visitor).active.includes(:created_by)
    @visitors = @visitors.search(params[:q]) if params[:q].present?
    @visitors = @visitors.where(visit_type: params[:visit_type]) if params[:visit_type].present?
    @visitors = @visitors.where(visitor_in_out: params[:in_out]) if params[:in_out].present?
    @pagy, @visitors = pagy(@visitors.order(created_at: :desc), items: 10)
  end

  def show
    authorize @visitor
  end

  def new
    authorize Visitor
    @visitor = Visitor.new(created_by: current_user)
  end

  def edit
    authorize @visitor
  end

  def create
    authorize Visitor
    @visitor = Visitor.new(visitor_params.merge(created_by: current_user))

    if @visitor.save
      redirect_to @visitor, notice: "Visitor pass #{@visitor.pass_code} issued successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @visitor
    if @visitor.update(visitor_params)
      redirect_to @visitor, notice: "Visitor updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @visitor
    @visitor.update!(is_deleted: true, status: false)
    redirect_to visitors_path, notice: "Visitor pass revoked and archived."
  end

  def generate_otp
    authorize @visitor, :generate_otp?
    @otp = @visitor.generate_otp!
    if @otp
      flash.now[:notice] = "OTP sent (shown once for security verification)."
    else
      flash.now[:alert] = "OTP requests exceeded for this pass. Archive and reissue."
    end
    render :show
  end

  def check_in
    authorize @visitor, :check_in?
    if @visitor.verify_otp(params[:otp])
      @visitor.mark_checked_in!
      redirect_to @visitor, notice: "Visitor checked in successfully under pass #{@visitor.pass_code}."
    else
      redirect_to @visitor, alert: "Invalid or expired OTP."
    end
  end

  def check_out
    authorize @visitor, :check_out?
    @visitor.mark_checked_out!
    redirect_to @visitor, notice: "Visitor checked out successfully."
  end

  private

  def set_visitor
    @visitor = Visitor.includes(:created_by).find(params[:id])
  end

  def visitor_params
    params.require(:visitor).permit(
      :name, :contact_no, :purpose, :site_id, :status, :start_pass, :end_pass,
      :coming_from, :vehicle_number, :expected_date, :expected_time, :skip_host_approval,
      :goods_inwards, :visit_type, :frequency, :working_days, :pass_number,
      :visitor_staff_category_id, :parking_slot, :visitor_in_out, :vhost_id, :verified,
      :pass_start_date, :pass_end_date, :building_id, :unit_id, :floor_id, :parent_id,
      :driving_license, :consignment_form, :qr_pending_expiry_minutes, :start_date,
      :end_date, :no_of_goods, :is_synced_with_hardware, working_days: []
    )
  end
end
