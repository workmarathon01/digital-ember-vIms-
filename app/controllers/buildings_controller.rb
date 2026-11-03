class BuildingsController < ApplicationController
  before_action :set_building, only: %i[show edit update destroy]
  before_action :load_sites, only: %i[new create edit update]

  def index
    authorize Building
    @buildings = policy_scope(Building).includes(:site).order("sites.name", :name)
    @buildings = @buildings.where(site_id: params[:site_id]) if params[:site_id].present?
    @buildings = @buildings.search(params[:q]) if params[:q].present?
    @pagy, @buildings = pagy(@buildings, items: 25)
    @sites = policy_scope(Site).order(:name)
  end

  def show
    authorize @building
    @floors = @building.floors.ordered
    @units = @building.units.includes(:floor).order(:name).limit(50)
    @user_sites = @building.user_sites.includes(:user, :unit, :floor).recent_first.limit(25)
  end

  def new
    authorize Building
    @building = Building.new(site_id: params[:site_id])
  end

  def create
    authorize Building
    attrs = building_params
    ensure_site_access!(attrs[:site_id])
    @building = Building.new(attrs)

    if @building.save
      respond_to do |format|
        format.html { redirect_to @building, notice: "Building #{@building.name} created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_validation_errors(@building) }
      end
    end
  end

  def edit
    authorize @building
  end

  def update
    authorize @building
    attrs = building_params
    ensure_site_access!(attrs[:site_id])

    if @building.update(attrs)
      respond_to do |format|
        format.html { redirect_to @building, notice: "Building updated successfully." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_validation_errors(@building) }
      end
    end
  end

  def destroy
    authorize @building

    if @building.destroy
      respond_to do |format|
        format.html { redirect_to buildings_path, notice: "Building removed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @building, alert: @building.errors.full_messages.to_sentence }
        format.json { render_delete_errors(@building) }
      end
    end
  end

  private

  def set_building
    @building = policy_scope(Building).find(params[:id])
  end

  def load_sites
    @sites = policy_scope(Site).active.order(:name)
  end

  def building_params
    params.require(:building).permit(:site_id, :name, :code, :description)
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
