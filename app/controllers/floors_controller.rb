class FloorsController < ApplicationController
  before_action :set_floor, only: %i[show edit update destroy]
  before_action :load_options, only: %i[new create edit update]

  def index
    authorize Floor
    @floors = policy_scope(Floor).includes(:site, :building).order("sites.name", "buildings.name", :level, :name)
    @floors = @floors.where(site_id: params[:site_id]) if params[:site_id].present?
    @floors = @floors.where(building_id: params[:building_id]) if params[:building_id].present?
    @floors = @floors.search(params[:q]) if params[:q].present?
    @pagy, @floors = pagy(@floors, items: 25)
    @sites = policy_scope(Site).order(:name)
    @buildings = policy_scope(Building).includes(:site).order("sites.name", :name)
  end

  def show
    authorize @floor
    @units = @floor.units.includes(:building).order(:name)
    @user_sites = @floor.user_sites.includes(:user, :unit).recent_first.limit(25)
  end

  def new
    authorize Floor
    @floor = Floor.new(building_id: params[:building_id])
  end

  def create
    authorize Floor
    attrs = floor_params
    ensure_site_access!(Building.find_by(id: attrs[:building_id])&.site_id)
    @floor = Floor.new(attrs)

    if @floor.save
      respond_to do |format|
        format.html { redirect_to @floor, notice: "Floor #{@floor.name} created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_validation_errors(@floor) }
      end
    end
  end

  def edit
    authorize @floor
  end

  def update
    authorize @floor
    attrs = floor_params
    ensure_site_access!(Building.find_by(id: attrs[:building_id])&.site_id)

    if @floor.update(attrs)
      respond_to do |format|
        format.html { redirect_to @floor, notice: "Floor updated successfully." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_validation_errors(@floor) }
      end
    end
  end

  def destroy
    authorize @floor

    if @floor.destroy
      respond_to do |format|
        format.html { redirect_to floors_path, notice: "Floor removed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @floor, alert: @floor.errors.full_messages.to_sentence }
        format.json { render_delete_errors(@floor) }
      end
    end
  end

  private

  def set_floor
    @floor = policy_scope(Floor).find(params[:id])
  end

  def load_options
    @sites = policy_scope(Site).active.order(:name)
    @buildings = policy_scope(Building).includes(:site).order("sites.name", :name)
  end

  def floor_params
    params.require(:floor).permit(:building_id, :name, :level, :description)
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
