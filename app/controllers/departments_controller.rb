class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[show update destroy]

  def index
    authorize Department
    @departments = policy_scope(Department).includes(:users).ordered
    @departments = @departments.search(params[:q]) if params[:q].present?
    @departments = @departments.where(active: params[:status] != "inactive") if params[:status].present?
  end

  def show
    authorize @department
  end

  def create
    authorize Department
    attrs = department_params
    ensure_site_access!(attrs[:site_id])
    attrs[:site_id] ||= current_site&.id
    @department = Department.new(attrs)

    if @department.save
      render :show, status: :created
    else
      render_validation_errors(@department)
    end
  end

  def update
    authorize @department
    attrs = department_params
    ensure_site_access!(attrs[:site_id])
    # Keep legacy departments attached to whichever site is editing them; a
    # site-scoped user must not be able to turn one into a global department.
    attrs[:site_id] ||= @department.site_id || current_site&.id

    if @department.update(attrs)
      render :show, status: :ok
    else
      render_validation_errors(@department)
    end
  end

  def destroy
    authorize @department

    if @department.destroy
      head :no_content
    else
      render_delete_errors(@department)
    end
  end

  private

  def set_department
    @department = policy_scope(Department).find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :code, :description, :active, :site_id)
  end

  def render_validation_errors(record)
    render json: { error: { code: "validation_failed", message: record.errors.full_messages.join(", ") } },
           status: :unprocessable_entity
  end

  def render_delete_errors(record)
    render json: { error: { code: "delete_blocked", message: record.errors.full_messages.to_sentence } },
           status: :unprocessable_entity
  end
end
