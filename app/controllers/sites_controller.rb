class SitesController < ApplicationController
  before_action :set_site, only: %i[show edit update destroy]
  before_action :load_feature_options, only: %i[new create edit update]

  def index
    authorize Site
    @sites = policy_scope(Site).includes(:site_features).order(:name)
    @sites = @sites.search(params[:q]) if params[:q].present?
    @sites = @sites.where(active: params[:status] != "inactive") if params[:status].present?
    @pagy, @sites = pagy(@sites, items: 25)
  end

  def show
    authorize @site
    load_site_details
  end

  def new
    authorize Site
    @site = Site.new(active: true, country: "India")
  end

  def create
    authorize Site
    @site = Site.new(site_params)

    if @site.save
      sync_site_features(apply_defaults: true)
      load_site_details
      respond_to do |format|
        format.html { redirect_to @site, notice: "Site #{@site.display_name} created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_validation_errors(@site) }
      end
    end
  end

  def edit
    authorize @site
  end

  def update
    authorize @site

    if @site.update(site_params)
      sync_site_features
      load_site_details
      respond_to do |format|
        format.html { redirect_to @site, notice: "Site updated successfully." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_validation_errors(@site) }
      end
    end
  end

  def destroy
    authorize @site

    if @site.destroy
      respond_to do |format|
        format.html { redirect_to sites_path, notice: "Site removed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @site, alert: @site.errors.full_messages.to_sentence }
        format.json { render_delete_errors(@site) }
      end
    end
  end

  private

  def set_site
    @site = policy_scope(Site).find(params[:id])
  end

  def site_params
    params.require(:site).permit(
      :name, :code, :region, :address, :city, :state, :country, :postal_code,
      :timezone, :latitude, :longitude, :active, :description
    )
  end

  def load_feature_options
    @features = Feature.active.ordered
  end

  def load_site_details
    @buildings = @site.buildings.includes(:floors).order(:name)
    @floors = @site.floors.includes(:building).ordered
    @units = @site.units.includes(:building, :floor).order(:name).limit(50)
    @user_sites = @site.user_sites.includes(:user, :unit, :building, :floor).recent_first.limit(25)
    @site_features = @site.enabled_features
  end

  def sync_site_features(apply_defaults: false)
    return unless current_user.can?(:site_features, :update)

    attributes = params[:site]
    if attributes.key?(:feature_ids)
      @site.sync_features!(attributes[:feature_ids], actor: current_user)
    elsif apply_defaults
      @site.sync_features!(Feature.active.where(default_enabled: true).pluck(:id), actor: current_user)
    end
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
