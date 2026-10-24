class UnitsController < ApplicationController
  before_action :set_unit, only: %i[show edit update destroy]
  before_action :load_options, only: %i[new create edit update]
  before_action :load_filters, only: :index

  def index
    authorize Unit
    @units = policy_scope(Unit).includes(:site, :building, :floor).order("sites.name", "buildings.name", "floors.level", "units.name")
    @units = @units.where(site_id: params[:site_id]) if params[:site_id].present?
    @units = @units.where(building_id: params[:building_id]) if params[:building_id].present?
    @units = @units.where(floor_id: params[:floor_id]) if params[:floor_id].present?
    @units = @units.where(status: params[:status]) if params[:status].present?
    @units = @units.search(params[:q]) if params[:q].present?
    @pagy, @units = pagy(@units, items: 25)
  end

  def show
    authorize @unit
    @user_sites = @unit.user_sites.includes(:user).recent_first
  end

  def new
    authorize Unit
    @unit = Unit.new(floor_id: params[:floor_id], status: "active")
  end

  def create
    authorize Unit
    @unit = Unit.new(unit_params)

    if @unit.save
      respond_to do |format|
        format.html { redirect_to @unit, notice: "Unit #{@unit.name} created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_validation_errors(@unit) }
      end
    end
  end

  def edit
    authorize @unit
  end

  def update
    authorize @unit

    if @unit.update(unit_params)
      respond_to do |format|
        format.html { redirect_to @unit, notice: "Unit updated successfully." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_validation_errors(@unit) }
      end
    end
  end

  def destroy
    authorize @unit

    if @unit.destroy
      respond_to do |format|
        format.html { redirect_to units_path, notice: "Unit removed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @unit, alert: @unit.errors.full_messages.to_sentence }
        format.json { render_delete_errors(@unit) }
      end
    end
  end

  private

  def set_unit
    @unit = Unit.find(params[:id])
  end

  def load_options
    @floors = Floor.includes(:site, :building).order("sites.name", "buildings.name", :level, :name)
  end

  def load_filters
    @sites = Site.order(:name)
    @buildings = Building.includes(:site).order("sites.name", :name)
    @floors = Floor.includes(:site, :building).order("sites.name", "buildings.name", :level, :name)
  end

  def unit_params
    params.require(:unit).permit(:floor_id, :name, :unit_type, :carpet_area, :status, :description)
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
