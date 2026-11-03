class StaffsController < ApplicationController
  before_action :set_staff, only: %i[show edit update destroy approve suspend punch_in punch_out]
  before_action :load_property_options, only: %i[new create edit update]

  def index
    authorize Staff
    @staffs = policy_scope(Staff).includes(:created_by, :site, :unit)
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
    @staff = Staff.new(created_by: current_user, site_id: current_site&.id)
  end

  def edit
    authorize @staff
  end

  def create
    authorize Staff
    attrs = staff_params
    ensure_site_access!(attrs[:site_id])
    if attrs[:unit_id].present?
      unit = Unit.find_by(id: attrs[:unit_id])
      ensure_site_access!(unit&.site_id)
      attrs[:site_id] ||= unit&.site_id
    end
    attrs[:site_id] ||= current_site&.id
    @staff = Staff.new(attrs.merge(created_by: current_user))

    if @staff.save
      respond_to do |format|
        format.html { redirect_to @staff, notice: "Staff #{@staff.staff_id} created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: { code: "validation_failed", message: @staff.errors.full_messages.join(", ") } }, status: :unprocessable_entity }
      end
    end
  end

  def update
    authorize @staff
    attrs = staff_params
    ensure_site_access!(attrs[:site_id])
    if attrs[:unit_id].present?
      ensure_site_access!(Unit.find_by(id: attrs[:unit_id])&.site_id)
    end
    attrs[:site_id] ||= @staff.site_id || current_site&.id

    if @staff.update(attrs)
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
    @staff = policy_scope(Staff).includes(:created_by).find(params[:id])
  end

  def staff_params
    params.require(:staff).permit(
      :firstname, :lastname, :email, :mobile_no, :work_type, :vendor_id,
      :valid_from, :valid_till, :status, :site_id, :longitude, :latitude,
      :status_type, :date_of_birth, :staff_in_out, :joining_date, :unit_id,
      working_schedule: Date::DAYNAMES.index_with([ :selected, :start_time, :end_time ])
    )
  end

  def load_property_options
    @sites = policy_scope(Site).active.order(:name)
    @units = policy_scope(Unit).includes(:site, :building, :floor).order("sites.name", "buildings.name", "floors.level", "units.name")
  end
end
