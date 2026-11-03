class FeaturesController < ApplicationController
  before_action :set_feature, only: %i[show edit update destroy]
  before_action :load_available_templates, only: %i[new create]

  def templates
    authorize Feature, :index?
    render json: Feature::STANDARD_TEMPLATES
  end

  def index
    authorize Feature
    @features = policy_scope(Feature).includes(:site_features).ordered
    @features = @features.search(params[:q]) if params[:q].present?
    @features = @features.where(category: params[:category]) if params[:category].present?
    @features = @features.where(active: params[:status] != "inactive") if params[:status].present?
    @pagy, @features = pagy(@features, items: 25)
  end

  def show
    authorize @feature
    @sites = policy_scope(Site).where(id: @feature.site_ids).order(:name)
  end

  def new
    authorize Feature
    @feature = Feature.new(active: true, sort_order: Feature.maximum(:sort_order).to_i + 1)
  end

  def create
    authorize Feature
    @feature = Feature.new(feature_params)

    if @feature.save
      @sites = @feature.sites.order(:name)
      respond_to do |format|
        format.html { redirect_to @feature, notice: "Feature #{@feature.name} created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_validation_errors(@feature) }
      end
    end
  end

  def edit
    authorize @feature
  end

  def update
    authorize @feature

    if @feature.update(feature_params)
      @sites = @feature.sites.order(:name)
      respond_to do |format|
        format.html { redirect_to @feature, notice: "Feature updated successfully." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_validation_errors(@feature) }
      end
    end
  end

  def destroy
    authorize @feature

    if @feature.destroy
      respond_to do |format|
        format.html { redirect_to features_path, notice: "Feature removed." }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to @feature, alert: @feature.errors.full_messages.to_sentence }
        format.json { render_delete_errors(@feature) }
      end
    end
  end

  private

  def set_feature
    @feature = Feature.find(params[:id])
  end

  def load_available_templates
    existing_keys = Feature.where(key: Feature::STANDARD_TEMPLATES.map { |template| template[:key] }).pluck(:key)
    @available_templates = Feature::STANDARD_TEMPLATES.reject { |template| existing_keys.include?(template[:key]) }
  end

  def feature_params
    params.require(:feature).permit(
      :key, :name, :description, :category, :icon,
      :default_enabled, :active, :sort_order
    )
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
