class BannersController < ApplicationController
  before_action :set_banner, only: %i[show edit update destroy]
  before_action :load_sites, only: %i[index new create edit update]

  def index
    authorize Banner
    @banners = policy_scope(Banner).includes(:site).with_attached_attachments

    if params[:site_id].present?
      ensure_site_access!(params[:site_id])
      @banners = @banners.where(site_id: params[:site_id])
    elsif current_site.present?
      @banners = @banners.where(site_id: current_site.id)
    end

    @banners = @banners.where(active: params[:status] != "inactive") if params[:status].present?
    @banners = @banners.where("banners.title ILIKE :term", term: "%#{params[:q].to_s.strip}%") if params[:q].present?
    @pagy, @banners = pagy(@banners.ordered, items: 25)
  end

  def show
    authorize @banner
  end

  def new
    authorize Banner
    @banner = Banner.new(
      site_id: params[:site_id].presence || current_site&.id,
      active: true,
      sort_order: 0,
      external_urls: []
    )
  end

  def create
    authorize Banner
    attrs = banner_params
    attrs[:site_id] ||= current_site&.id
    ensure_site_access!(attrs[:site_id])
    @banner = Banner.new(attrs)

    if @banner.save
      purge_removed_attachments
      respond_to do |format|
        format.html { redirect_to @banner, notice: "Banner created successfully." }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render_validation_errors(@banner) }
      end
    end
  end

  def edit
    authorize @banner
  end

  def update
    authorize @banner
    attrs = banner_params
    ensure_site_access!(attrs[:site_id]) if attrs.key?(:site_id)

    if @banner.update(attrs)
      purge_removed_attachments
      respond_to do |format|
        format.html { redirect_to @banner, notice: "Banner updated successfully." }
        format.json { render :show, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render_validation_errors(@banner) }
      end
    end
  end

  def destroy
    authorize @banner

    @banner.destroy
    respond_to do |format|
      format.html { redirect_to banners_path, notice: "Banner removed." }
      format.json { head :no_content }
    end
  end

  private

  def set_banner
    @banner = policy_scope(Banner).find(params[:id])
  end

  def load_sites
    @sites = policy_scope(Site).active.order(:name)
  end

  def banner_params
    attributes = params.require(:banner).permit(
      :site_id, :title, :description, :active, :sort_order,
      attachments: [], remove_attachment_ids: []
    )
    attributes.delete(:remove_attachment_ids)
    if params[:banner].key?(:external_urls)
      attributes[:external_urls] = params[:banner][:external_urls]
    end
    attributes
  end

  def purge_removed_attachments
    ids = Array(params.dig(:banner, :remove_attachment_ids)).reject(&:blank?)
    return if ids.empty?

    @banner.attachments.where(id: ids).each(&:purge)
    @banner.attachments.reset
  end

  def render_validation_errors(record)
    render json: { error: { code: "validation_failed", message: record.errors.full_messages.join(", ") } },
           status: :unprocessable_entity
  end
end
