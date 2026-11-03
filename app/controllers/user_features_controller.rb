class UserFeaturesController < ApplicationController
  before_action :set_user
  before_action :set_site

  def show
    authorize UserFeature
    load_feature_state

    respond_to do |format|
      format.html { redirect_to user_path(@user) }
      format.json
    end
  end

  def update
    authorize UserFeature, :update?

    if @site.blank?
      respond_to do |format|
        format.html { redirect_to user_path(@user), alert: "Select a site before updating feature access." }
        format.json do
          render json: { error: { code: "site_required", message: "Select a site before updating feature access." } },
                 status: :unprocessable_entity
        end
      end
      return
    end

    @user.sync_feature_overrides!(@site, overrides, actor: current_user)
    load_feature_state

    respond_to do |format|
      format.html { redirect_to user_path(@user), notice: "Feature access updated for #{@user.full_name}." }
      format.json { render :show, status: :ok }
    end
  end

  private

  def set_user
    @user = policy_scope(User).find(params[:user_id])
  end

  def set_site
    @site = policy_scope(Site).find_by(id: params[:site_id]) ||
            policy_scope(Site).find_by(id: @user.current_site_id)
  end

  def load_feature_state
    @features = @site.present? ? @site.enabled_features : Feature.none
    @effective_feature_ids = @site.present? ? @user.effective_features(@site).pluck(:id) : []
    @override_states = @user.user_features.where(site_id: @site&.id).pluck(:feature_id, :enabled)
                             .to_h { |feature_id, enabled| [ feature_id, enabled ? "granted" : "revoked" ] }
  end

  def overrides
    params[:overrides].respond_to?(:to_unsafe_h) ? params[:overrides].to_unsafe_h : params[:overrides]
  end
end
