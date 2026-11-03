class UserSitesController < ApplicationController
  before_action :set_user_site, only: %i[destroy make_primary]

  def index
    authorize UserSite
    @user_sites = policy_scope(UserSite).includes(:user, :site, :building, :floor, :unit).recent_first
    @user_sites = @user_sites.where(user_id: params[:user_id]) if params[:user_id].present?
    @user_sites = @user_sites.where(site_id: params[:site_id]) if params[:site_id].present?
    @user_sites = @user_sites.where(unit_id: params[:unit_id]) if params[:unit_id].present?
    @pagy, @user_sites = pagy(@user_sites, items: 25)
  end

  def create
    authorize UserSite
    @user_site = UserSite.new(user_site_params)
    ensure_location_access!
    ensure_target_user_access!

    if @user_site.save
      respond_to do |format|
        format.html do
          redirect_to user_path(@user_site.user), notice: "Residence associated with #{@user_site.user.full_name}."
        end
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          redirect_back fallback_location: user_sites_path, alert: @user_site.errors.full_messages.to_sentence
        end
        format.json do
          render json: { error: { code: "validation_failed", message: @user_site.errors.full_messages.join(", ") } },
                 status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    authorize @user_site
    user = @user_site.user
    @user_site.destroy

    respond_to do |format|
      format.html { redirect_to user_path(user), notice: "Residence association removed." }
      format.json { head :no_content }
    end
  end

  def make_primary
    authorize @user_site, :make_primary?

    if @user_site.update(is_primary: true)
      respond_to do |format|
        format.html { redirect_to user_path(@user_site.user), notice: "Primary residence updated." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to user_path(@user_site.user), alert: @user_site.errors.full_messages.to_sentence }
        format.json do
          render json: { error: { code: "validation_failed", message: @user_site.errors.full_messages.join(", ") } },
                 status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_user_site
    @user_site = policy_scope(UserSite).find(params[:id])
  end

  # The residence location is derived from unit/floor/building, so check all
  # of them before the model fills `site_id` in.
  def ensure_location_access!
    ensure_site_access!(@user_site.site_id)
    ensure_site_access!(@user_site.building&.site_id)
    ensure_site_access!(@user_site.floor&.site_id)
    ensure_site_access!(@user_site.unit&.site_id)
  end

  def ensure_target_user_access!
    return unless site_restricted?
    return if policy_scope(User).exists?(id: @user_site.user_id)

    raise Pundit::NotAuthorizedError
  end

  def user_site_params
    params.require(:user_site).permit(
      :user_id, :site_id, :building_id, :floor_id, :unit_id, :ownership,
      :is_primary, :lives_here, :is_approved, :move_in_date, :move_out_date
    )
  end
end
