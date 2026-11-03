class SiteFeaturesController < ApplicationController
  before_action :set_site

  def show
    authorize SiteFeature
    load_feature_state

    respond_to do |format|
      format.html { redirect_to edit_site_path(@site) }
      format.json
    end
  end

  def update
    authorize SiteFeature, :update?

    @site.sync_features!(feature_ids, actor: current_user)
    load_feature_state

    respond_to do |format|
      format.html { redirect_to site_path(@site), notice: "Feature access updated for #{@site.display_name}." }
      format.json { render :show, status: :ok }
    end
  end

  private

  def set_site
    @site = policy_scope(Site).find(params[:site_id])
  end

  def load_feature_state
    @features = Feature.active.ordered
    @enabled_feature_ids = @site.enabled_feature_ids
  end

  def feature_ids
    values = params.dig(:site_feature, :feature_ids) || params[:feature_ids] || []
    Array(values)
  end
end
