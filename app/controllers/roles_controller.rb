class RolesController < ApplicationController
  before_action :set_role, only: %i[show edit update destroy]

  def index
    authorize Role
    @roles = policy_scope(Role).includes(:permissions).order(power_level: :desc, name: :asc)
  end

  def show
    authorize @role
    @members = @role.users.active.includes(:role).order(created_at: :desc).limit(20)
  end

  def new
    authorize Role
    @role = Role.new
    @role.is_system = false
  end

  def edit
    authorize @role
  end

  def create
    authorize Role
    @role = Role.new(role_params)

    if @role.save
      sync_permissions!
      redirect_to @role, notice: "Role #{@role.name} created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @role
    previous = @role.dup
    if @role.update(role_params)
      sync_permissions!
      redirect_to @role, notice: "Role #{@role.name} updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @role
    if @role.system?
      redirect_to roles_path, alert: "System roles cannot be deleted."
      return
    end

    @role.destroy
    redirect_to roles_path, notice: "Role deleted successfully."
  end

  private

  def set_role
    @role = Role.includes(:permissions).find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name, :key, :description, :active, :power_level)
  end

  def sync_permissions!
    granted = (params[:permissions] || {}).select { |_, v| v.to_s == "1" }.keys
    resources = Role::RESOURCES.map { |r| r[:key] }
    granted.filter! { |key| key.include?(":") && resources.include?(key.split(":").first) }

    resource, action = granted.map { |c| c.split(":", 2) }.transpose
    requested = Array(resource).zip(Array(action)).map { |res, act| { resource: res, action: act } }

    @role.permissions.destroy_all
    return if requested.empty?

    @role.permissions.insert_all(requested)
    @role.permissions.reset
  end
end
