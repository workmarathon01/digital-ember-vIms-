class VisitorsController < ApplicationController
  before_action :set_visitor, only: %i[show edit update destroy generate_otp check_in check_out send_pass]
  before_action :load_property_options, only: %i[new create edit update]

  def index
    authorize Visitor
    @visitors = policy_scope(Visitor).active.includes(:created_by, :site, :unit, :vhost, profile_image_attachment: :blob)
    @visitors = @visitors.search(params[:q]) if params[:q].present?
    @visitors = @visitors.where(visit_type: params[:visit_type]) if params[:visit_type].present?
    @visitors = @visitors.where(visitor_in_out: params[:in_out]) if params[:in_out].present?
    @pagy, @visitors = pagy(@visitors.order(created_at: :desc), items: 15)
  end

  def show
    authorize @visitor
    load_visitor_history
  end

  def new
    authorize Visitor
    @visitor = Visitor.new(
      { created_by: current_user, site_id: current_site&.id }.merge(employee_visitor_defaults)
    )
  end

  def edit
    authorize @visitor
  end

  def create
    authorize Visitor
    attrs = visitor_params
    apply_employee_defaults!(attrs)
    ensure_location_access!(attrs)
    attrs[:site_id] ||= current_site&.id
    # The creator is always the signed-in user. Accept the field from the
    # client for API symmetry, but never trust its value.
    attrs[:created_by_id] = current_user.id
    @visitor = Visitor.new(attrs.merge(created_by: current_user))
    add_expected_visit_errors(attrs)

    if @visitor.errors.empty? && @visitor.save
      respond_to do |format|
        format.html { redirect_to @visitor, notice: "Visitor pass #{@visitor.pass_code} issued successfully." }
        format.json { render :show, status: :created }
      end
    else
      render_visitor_errors
    end
  end

  def update
    authorize @visitor
    attrs = visitor_params
    # The original creator must never change when the visitor is edited.
    attrs.delete(:created_by_id)
    ensure_location_access!(attrs)
    attrs[:site_id] ||= @visitor.site_id || current_site&.id

    if @visitor.update(attrs)
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
    unless visitor_verified_for_gate?
      return render_gate_error("invalid_otp", "Invalid or expired OTP.")
    end

    result = VisitorGate.check_in(
      @visitor,
      occurred_at: movement_time,
      source: "staff",
      recorded_by: current_user,
      ip: request.remote_ip
    )

    render_gate_result(
      result,
      success_message: "Visitor checked in successfully under pass #{@visitor.pass_code}.",
      duplicate_message: "Visitor was already checked in; no new entry was recorded."
    )
  end

  def check_out
    authorize @visitor, :check_out?
    result = VisitorGate.check_out(
      @visitor,
      occurred_at: movement_time,
      source: "staff",
      recorded_by: current_user,
      ip: request.remote_ip
    )

    render_gate_result(result, success_message: "Visitor checked out successfully.")
  end

  # Re-send the public pass link to the visitor's mobile number.
  def send_pass
    authorize @visitor, :update?

    if @visitor.contact_no.blank?
      return redirect_to @visitor, alert: "This visitor has no mobile number on file."
    end

    VisitorPassNotificationJob.perform_later(@visitor.id)
    redirect_to @visitor, notice: "Pass link SMS queued for #{@visitor.contact_no}."
  end

  private

  def set_visitor
    @visitor = policy_scope(Visitor).includes(:created_by).find(params[:id])
  end

  def load_visitor_history
    @visitor_stays = @visitor.visit_history
    @current_stay = @visitor_stays.find(&:ongoing?)
    @visitor_movements = @visitor.visitor_movements.recent_first.includes(:recorded_by)
  end

  # Security desk, gate security and super admins identify the visitor in
  # person, so their movement does not need the pass OTP. Other roles keep the
  # existing OTP verification.
  def visitor_verified_for_gate?
    current_user.can_mark_visitor_directly? || @visitor.verify_otp(params[:otp])
  end

  def render_gate_result(result, success_message:, duplicate_message: nil)
    if result.success?
      message = result.duplicate? ? duplicate_message : success_message
      respond_to do |format|
        format.html { redirect_to @visitor, notice: message }
        format.json do
          load_visitor_history
          render :show, status: :ok
        end
      end
    else
      render_gate_error(result.error_code, result.error_message)
    end
  end

  def render_gate_error(code, message)
    respond_to do |format|
      format.html { redirect_to @visitor, alert: message }
      format.json do
        render json: { error: { code: code.to_s, message: message } },
               status: :unprocessable_entity
      end
    end
  end

  # Staff may back-date a movement from the visitor page. A blank or invalid
  # value falls back to the current time.
  def movement_time
    return Time.current if params[:occurred_at].blank?

    Time.zone.parse(params[:occurred_at].to_s) || Time.current
  rescue ArgumentError
    Time.current
  end

  def add_expected_visit_errors(attrs)
    @visitor.errors.add(:expected_date, "can't be blank") if attrs[:expected_date].blank?
    @visitor.errors.add(:expected_time, "can't be blank") if attrs[:expected_time].blank?
  end

  def render_visitor_errors
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json do
        render json: {
          error: {
            code: "validation_failed",
            message: @visitor.errors.full_messages.join(", ")
          }
        }, status: :unprocessable_entity
      end
    end
  end

  # Employees create visitors from their own workplace: use their unit,
  # building, floor and site, and make them the host unless another host was
  # explicitly chosen.
  def employee_visitor_defaults
    return {} unless current_user.employee?

    {
      building_id: current_user.building_id,
      floor_id: current_user.floor_id,
      unit_id: current_user.unit_id,
      vhost_id: current_user.id
    }.compact
  end

  def apply_employee_defaults!(attrs)
    return unless current_user.employee?

    default_site_id = current_user.current_site_id || current_site&.id
    attrs[:site_id] = attrs[:site_id].presence || default_site_id
    # Only inherit the employee's own location when the visitor is for that
    # site. A multi-site employee can deliberately pick another site.
    return unless attrs[:site_id].to_i == default_site_id.to_i

    attrs[:building_id] = attrs[:building_id].presence || current_user.building_id
    attrs[:floor_id] = attrs[:floor_id].presence || current_user.floor_id
    attrs[:unit_id] = attrs[:unit_id].presence || current_user.unit_id
    return if attrs[:vhost_id].present?

    unit_id = attrs[:unit_id].to_i
    attrs[:vhost_id] = current_user.id if unit_id.zero? || current_user.unit_id.to_i == unit_id
  end

  # A visitor can be attached through any location field in the payload, so
  # every one of them has to belong to the actor's site, not just `site_id`.
  def ensure_location_access!(attrs)
    ensure_site_access!(attrs[:site_id])
    ensure_site_access!(Building.find_by(id: attrs[:building_id])&.site_id) if attrs[:building_id].present?
    ensure_site_access!(Floor.find_by(id: attrs[:floor_id])&.site_id) if attrs[:floor_id].present?
    if attrs[:unit_id].present?
      unit = Unit.find_by(id: attrs[:unit_id])
      ensure_site_access!(unit&.site_id)
      attrs[:site_id] ||= unit&.site_id
    end
    return unless attrs[:vhost_id].present? && site_restricted?

    # The host only has to belong to the visitor's site. Do not run this
    # through UserPolicy, which hides super admins from regular user lists.
    site_id = attrs[:site_id] || current_site&.id
    raise Pundit::NotAuthorizedError unless site_id.present? && User.for_sites([ site_id ]).exists?(id: attrs[:vhost_id])
  end

  def visitor_params
    params.require(:visitor).permit(
      :name, :contact_no, :purpose, :site_id, :status, :start_pass, :end_pass, :created_by_id,
      :coming_from, :vehicle_number, :expected_date, :expected_time, :skip_host_approval,
      :goods_inwards, :visit_type, :frequency, :working_days, :pass_number,
      :visitor_staff_category_id, :parking_slot, :visitor_in_out, :vhost_id, :verified,
      :pass_start_date, :pass_end_date, :building_id, :unit_id, :floor_id, :parent_id,
      :driving_license, :consignment_form, :qr_pending_expiry_minutes, :start_date,
      :end_date, :no_of_goods, :is_synced_with_hardware, :profile_image, working_days: []
    )
  end

  def load_property_options
    @sites = policy_scope(Site).active.order(:name)
    @buildings = policy_scope(Building).includes(:site).order("sites.name", :name)
    @floors = policy_scope(Floor).includes(:site, :building).order("sites.name", "buildings.name", :level, :name)
    @units = policy_scope(Unit).includes(:site, :building, :floor).order("sites.name", "buildings.name", "floors.level", "units.name")
    @hosts = policy_scope(User).active.includes(:role).order(:firstname, :lastname)
  end
end
