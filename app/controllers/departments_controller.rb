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
    @department = Department.new(department_params)

    if @department.save
      render :show, status: :created
    else
      render_validation_errors(@department)
    end
  end

  def update
    authorize @department

    if @department.update(department_params)
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
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name, :code, :description, :active)
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
