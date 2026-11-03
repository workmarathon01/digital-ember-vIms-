module Public
  class VisitorsController < PublicController
    # GET /public/visitors/lookup?contact_no=...
    #
    # Looks up the latest pass for a phone number. When a visitor has registered
    # before, the self-registration screen prefills their details. No other
    # visitor data is exposed.
    def lookup
      contact_no = Visitor.normalize_contact_no(params[:contact_no])

      if contact_no.length < 10
        return render_public_error(
          "invalid_contact_no",
          "Enter a valid mobile number with at least 10 digits.",
          :unprocessable_entity
        )
      end

      @visitor = Visitor.latest_for_contact(contact_no)
      @registered = @visitor.present?

      current_pass = Visitor.active
                            .where(contact_no: contact_no)
                            .where("end_pass IS NULL OR end_pass >= ?", Time.current)
                            .order(created_at: :desc)
                            .first
      @currently_checked_in = current_pass&.checked_in? || false

      render :lookup
    end

    # POST /public/visitors
    #
    # Creates a new visitor pass. Reusing a phone number is allowed: a returning
    # visitor gets a fresh pass with their previous details prefilled, rather
    # than overwriting a historical record.
    def create
      @visitor = Visitor.new(visitor_params)
      @visitor.created_by = nil
      @visitor.status = true
      @visitor.verified = false
      @visitor.visitor_in_out = nil

      if @visitor.save
        render :create, status: :created
      else
        render_public_error(
          "validation_failed",
          @visitor.errors.full_messages.to_sentence,
          :unprocessable_entity
        )
      end
    end

    # GET /public/visitors/pass?token=...
    #
    # Public, read-only view of a visitor pass. Only the signed token embedded in
    # the SMS/email link is accepted here; bare pass codes stay limited to the
    # gate verification endpoint.
    def pass
      @visitor = Visitor.find_by_public_token(params[:token])

      if @visitor.nil?
        return render_public_error(
          "pass_not_found",
          "This pass link is invalid, expired or has been revoked.",
          :not_found
        )
      end

      response.headers["Cache-Control"] = "no-store"
      @found = true
      @already_checked_in = @visitor.checked_in?
      render :pass
    end

    # GET /public/visitors/verify?code=...
    #
    # Verifies a scanned QR token or a manually typed PASS-XXXXXXXX code.
    def verify
      @visitor = Visitor.find_by_scan_code(params[:code])

      if @visitor.nil?
        return render_public_error(
          "pass_not_found",
          "This pass could not be found. Check the code or register as a new visitor.",
          :not_found
        )
      end

      @found = true
      @already_checked_in = @visitor.checked_in?
      render :verify
    end

    # POST /public/visitors/check_in
    #
    # Idempotent check-in. A second scan returns the existing check-in time
    # instead of creating a duplicate entry.
    def check_in
      @visitor = Visitor.find_by_scan_code(params[:code])

      if @visitor.nil?
        return render_public_error(
          "pass_not_found",
          "This pass could not be found. Check the code or register as a new visitor.",
          :not_found
        )
      end

      unless @visitor.pass_active? || @visitor.checked_in?
        return render_public_error(
          "pass_inactive",
          "This pass is no longer active. Please register for a new pass.",
          :unprocessable_entity
        )
      end

      @already_checked_in = @visitor.checked_in?
      @visitor.mark_checked_in! unless @already_checked_in

      render :check_in
    end

    # GET /public/hosts?unit_id=...
    #
    # Returns the residents/hosts linked to a unit so both the public and staff
    # visitor forms can offer a host dropdown after a unit is selected.
    def hosts
      unit_id = params[:unit_id].to_i

      if unit_id <= 0 || !Unit.active.exists?(id: unit_id)
        return render_public_error(
          "invalid_unit",
          "Select a valid unit to load its hosts.",
          :unprocessable_entity
        )
      end

      @hosts = User.hosts_for_unit(unit_id)
      render :hosts
    end

    # GET /public/form_options
    #
    # Minimal property directory used to populate the public self-registration
    # form without exposing residents, users, or contact information.
    def form_options
      @sites = Site.active.order(:name)
      @units = Unit.active
                   .includes(:site, :building, :floor)
                   .order("sites.name", "buildings.name", "floors.level", "units.name")

      render :form_options
    end

    private

    def visitor_params
      params.require(:visitor).permit(
        :name, :contact_no, :purpose, :coming_from, :vehicle_number, :visit_type,
        :expected_date, :expected_time, :site_id, :building_id, :floor_id, :unit_id,
        :vhost_id, :profile_image,
        :start_pass, :end_pass, :pass_start_date, :pass_end_date, :frequency,
        :no_of_goods, :goods_inwards, :working_days
      )
    end
  end
end
