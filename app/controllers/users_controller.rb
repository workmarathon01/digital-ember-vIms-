class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy lock unlock approve_registration reject_registration]
  before_action :load_property_options, only: %i[new create edit update show]

  def index
    authorize User
    @users = policy_scope(User).with_role
                              .includes(:current_site, :unit, profile_image_attachment: :blob)
                              .order(created_at: :desc)
    @users = @users.search(params[:q]) if params[:q].present?
    @users = @users.where(role_id: params[:role_id]) if params[:role_id].present?
    @pagy, @users = pagy(@users, limit: 10)
    @roles = assignable_roles
    load_pending_registrations
  end

  # GET /users/pending_registrations
  #
  # JSON-friendly queue of employee self-registrations waiting for review.
  def pending_registrations
    authorize User, :index?
    @pagy, @pending_registrations = pagy(
      policy_scope(User).pending_registration
                        .includes(:current_site, profile_image_attachment: :blob)
                        .order(registration_submitted_at: :asc, created_at: :asc),
      limit: 25
    )

    respond_to do |format|
      format.html
      format.json
    end
  end

  def show
    authorize @user
    load_user_details
    # Never expose another site's feature overrides on a multi-site resident.
    @feature_site = policy_scope(Site).find_by(id: @user.current_site_id) || current_site
    @available_features = @feature_site.present? ? @feature_site.enabled_features : Feature.none
    @effective_feature_ids = @feature_site.present? ? @user.effective_features(@feature_site).pluck(:id) : []
    @override_states = @user.user_features.where(site_id: @feature_site&.id).pluck(:feature_id, :enabled)
                            .to_h { |feature_id, enabled| [ feature_id, enabled ? "granted" : "revoked" ] }
  end

  def new
    authorize User
    @user = User.new(active: true, current_site_id: current_site&.id)
  end

  def edit
    authorize @user
  end

  def create
    authorize User
    attrs = create_params
    attrs.delete(:role_id) unless current_user.can?(:users, :assign_roles)
    assign_site_for_write!(attrs)
    @user = User.new(attrs)
    role_allowed = role_assignment_allowed?(attrs[:role_id])
    @user.errors.add(:role, "cannot be assigned") unless role_allowed

    if role_allowed && @user.save
      respond_to do |format|
        format.html { redirect_to @user, notice: "User created successfully." }
        format.json do
          load_user_details
          render :show, status: :created
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { error: { code: "validation_failed", message: @user.errors.full_messages.join(", ") } }, status: :unprocessable_entity }
      end
    end
  end

  def update
    authorize @user
    attrs = update_params
    attrs.delete(:password) if attrs[:password].blank?
    attrs.delete(:role_id) unless current_user.can?(:users, :assign_roles)
    assign_site_for_write!(attrs)
    role_allowed = role_assignment_allowed?(attrs[:role_id])
    @user.errors.add(:role, "cannot be assigned") unless role_allowed

    if role_allowed && @user.update(attrs)
      respond_to do |format|
        format.html { redirect_to @user, notice: "User updated successfully." }
        format.json do
          load_user_details
          render :show, status: :ok
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { error: { code: "validation_failed", message: @user.errors.full_messages.join(", ") } }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    authorize @user
    @user.update!(active: false)
    redirect_to users_path, notice: "User account deactivated."
  end

  def lock
    authorize @user, :lock?
    @user.register_failed_login! until @user.locked_at.present?
    AuditLog.create!(actor: current_user, action: "lock", resource_type: "User", resource_id: @user.id,
                     ip_address: request.remote_ip, user_agent: request.user_agent)
    redirect_to @user, notice: "User account locked."
  end

  def unlock
    authorize @user, :unlock?
    @user.unlock!
    AuditLog.create!(actor: current_user, action: "unlock", resource_type: "User", resource_id: @user.id,
                     ip_address: request.remote_ip, user_agent: request.user_agent)
    redirect_to @user, notice: "User account unlocked."
  end

  # POST /users/:id/approve_registration
  def approve_registration
    authorize @user, :approve?
    @user.approve_registration!(current_user, note: params[:note])
    audit_registration("approve_registration", @user)

    respond_to do |format|
      format.html { redirect_to users_path, notice: "#{@user.full_name}'s employee registration was approved." }
      format.json do
        load_user_details
        render :show, status: :ok
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_registration_error(e.record.errors.full_messages.to_sentence)
  end

  # POST /users/:id/reject_registration
  def reject_registration
    authorize @user, :reject?
    @user.reject_registration!(current_user, note: params[:note])
    audit_registration("reject_registration", @user)

    respond_to do |format|
      format.html { redirect_to users_path, notice: "#{@user.full_name}'s employee registration was rejected." }
      format.json do
        load_user_details
        render :show, status: :ok
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    respond_registration_error(e.record.errors.full_messages.to_sentence)
  end

  private

  def load_pending_registrations
    @pending_registrations = policy_scope(User).pending_registration
                                              .includes(:current_site, profile_image_attachment: :blob)
                                              .order(registration_submitted_at: :asc, created_at: :asc)
                                              .limit(25)
  end

  def audit_registration(action, user)
    AuditLog.create!(
      actor: current_user,
      action: action,
      resource_type: "User",
      resource_id: user.id,
      details: { registration_status: user.registration_status, note: user.registration_note },
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  def respond_registration_error(message)
    respond_to do |format|
      format.html { redirect_to users_path, alert: message }
      format.json { render json: { error: { code: "registration_review_failed", message: message } }, status: :unprocessable_entity }
    end
  end

  def set_user
    @user = policy_scope(User).includes(:role, profile_image_attachment: :blob).find(params[:id])
  end

  def load_user_details
    @user_sites = policy_scope(UserSite).where(user_id: @user.id)
                                       .includes(:site, :building, :floor, :unit).recent_first
    @audit_logs = policy_scope(AuditLog).newest_first.where(actor: @user).includes(:actor).limit(10)
  end

  def create_params
    params.require(:user).permit(
      :email, :password, :firstname, :lastname, :active, :user_type,
      :company_id, :mobile, :unit_id, :current_site_id, :building_id, :floor_id, :role_id,
      :department_id, :profile_image
    )
  end

  def update_params
    params.require(:user).permit(
      :firstname, :lastname, :email, :mobile, :password, :user_type, :company_id,
      :unit_id, :current_site_id, :building_id, :floor_id, :role_id, :active, :user_courtesy, :user_phase,
      :birth_date, :anniversary, :spouse_birth_date, :email_1, :email_2, :landline_number,
      :intercom_number, :user_address, :resident_type, :membership_type, :lives_here,
      :allow_fitout, :no_of_adults, :no_of_childrens, :no_of_pets, :differently_abled,
      :department_id, :designation_id, :manager_id, :about_me, :position,
      :organization_id, :blood_group, :profession, :location, :sub_location,
      :start_date, :end_date, :date_of_joining, :profile_image
    )
  end

  def load_property_options
    @sites = policy_scope(Site).active.order(:name)
    @buildings = policy_scope(Building).includes(:site).order("sites.name", :name)
    @floors = policy_scope(Floor).includes(:site, :building).order("sites.name", "buildings.name", :level, :name)
    @units = policy_scope(Unit).includes(:site, :building, :floor).order("sites.name", "buildings.name", "floors.level", "units.name")
    @departments = policy_scope(Department).order(:name)
    @assignable_roles = assignable_roles
  end

  # Site-scoped staff can only create or move users inside their own sites.
  # When the form leaves the site blank, the user joins the actor's site.
  def assign_site_for_write!(attrs)
    return unless site_restricted?

    requested = attrs[:current_site_id].presence
    ensure_site_access!(requested)

    if attrs[:building_id].present?
      ensure_site_access!(Building.find_by(id: attrs[:building_id])&.site_id)
    end

    if attrs[:floor_id].present?
      ensure_site_access!(Floor.find_by(id: attrs[:floor_id])&.site_id)
    end

    if attrs[:unit_id].present?
      unit = Unit.find_by(id: attrs[:unit_id])
      ensure_site_access!(unit&.site_id)
      attrs[:current_site_id] ||= unit&.site_id
    end

    attrs[:current_site_id] ||= current_site&.id
  end

  def assignable_roles
    if current_user.super_admin?
      Role.active.order(:power_level)
    else
      Role.active.where.not(key: "super_admin").order(:power_level)
    end
  end

  def role_assignment_allowed?(role_id)
    return true if role_id.blank? || current_user.super_admin?

    Role.where(id: role_id).where.not(key: "super_admin").exists?
  end
end
