class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy lock unlock]
  before_action :load_property_options, only: %i[new create edit update show]

  def index
    authorize User
    @users = policy_scope(User).with_role.includes(:current_site, :unit).order(created_at: :desc)
    @users = @users.search(params[:q]) if params[:q].present?
    @users = @users.where(role_id: params[:role_id]) if params[:role_id].present?
    @pagy, @users = pagy(@users, items: 25)
    @roles = Role.active.order(:power_level)
  end

  def show
    authorize @user
    @user_sites = @user.user_sites.includes(:site, :building, :floor, :unit).recent_first
    @audit_logs = AuditLog.newest_first.where(actor: @user).includes(:actor).limit(10)
    @feature_site = @user.current_site
    @available_features = @feature_site.present? ? @feature_site.enabled_features : Feature.none
    @effective_feature_ids = @feature_site.present? ? @user.effective_features(@feature_site).pluck(:id) : []
    @override_states = @user.user_features.where(site_id: @feature_site&.id).pluck(:feature_id, :enabled)
                            .to_h { |feature_id, enabled| [ feature_id, enabled ? "granted" : "revoked" ] }
  end

  def new
    authorize User
    @user = User.new(active: true)
  end

  def edit
    authorize @user
  end

  def create
    authorize User
    @user = User.new(create_params)

    if @user.save
      respond_to do |format|
        format.html { redirect_to @user, notice: "User created successfully." }
        format.json do
          @user_sites = @user.user_sites.includes(:site, :building, :floor, :unit).recent_first
          @audit_logs = []
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

    if @user.update(attrs)
      redirect_to @user, notice: "User updated successfully."
    else
      render :edit, status: :unprocessable_entity
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

  private

  def set_user
    @user = User.includes(:role).find(params[:id])
  end

  def create_params
    params.require(:user).permit(
      :email, :password, :firstname, :lastname, :active, :user_type,
      :company_id, :mobile, :unit_id, :current_site_id, :building_id, :floor_id, :role_id
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
      :start_date, :end_date, :date_of_joining
    )
  end

  def load_property_options
    @sites = Site.active.order(:name)
    @units = Unit.includes(:site, :building, :floor).order("sites.name", "buildings.name", "floors.level", "units.name")
  end
end
