class StaffsController < ApplicationController
  before_action :set_staff, only: %i[show edit update destroy approve suspend punch_in punch_out]

  def index
    authorize Staff
    @staffs = policy_scope(Staff).includes(:created_by)
    @staffs = @staffs.search(params[:q]) if params[:q].present?
    @staffs = @staffs.where(status_type: params[:status]) if params[:status].present?
    @staffs = @staffs.approved if params[:only_approved] == "1"
    @pagy, @staffs = pagy(@staffs.order(created_at: :desc), items: 25)
  end

  def show
    authorize @staff
  end

  def new
    authorize Staff
    @staff = Staff.new(created_by: current_user)
  end

  def edit
    authorize @staff
  end

  def create
    authorize Staff
    @staff = Staff.new(staff_params.merge(created_by: current_user))

    if @staff.save
      redirect_to @staff, notice: "Staff #{@staff.staff_id} created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @staff
    if @staff.update(staff_params)
      redirect_to @staff, notice: "Staff updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @staff
    @staff.suspend!
    redirect_to staffs_path, notice: "Staff member suspended."
  end

  def approve
    authorize @staff, :approve?
    @staff.approve!
    redirect_to @staff, notice: "Staff #{@staff.full_name} approved."
  end

  def suspend
    authorize @staff, :suspend?
    @staff.suspend!
    redirect_to @staff, notice: "Staff #{@staff.full_name} suspended."
  end

  def punch_in
    authorize @staff, :punch_in?
    @staff.punch_in!(ip: request.remote_ip)
    redirect_to @staff, notice: "Staff punched in."
  end

  def punch_out
    authorize @staff, :punch_out?
    @staff.punch_out!(ip: request.remote_ip)
    redirect_to @staff, notice: "Staff punched out."
  end

  private

  def set_staff
    @staff = Staff.includes(:created_by).find(params[:id])
  end

  def staff_params
    params.require(:staff).permit(
      :firstname, :lastname, :email, :mobile_no, :work_type, :vendor_id,
      :valid_from, :valid_till, :status, :site_id, :longitude, :latitude,
      :status_type, :date_of_birth, :staff_in_out, :joining_date, :unit_id,
      working_schedule: Date::DAYNAMES.index_with([ :selected, :start_time, :end_time ])
    )
  end
end
