module Public
  # Public employee onboarding endpoint.
  #
  # A self-registered employee is created with user_type "employee", no role,
  # inactive account and registration_status "pending". An administrator or
  # super admin must approve the registration from the Users screen before the
  # account can sign in.
  class EmployeeRegistrationsController < PublicController
    # GET /public/employee_registrations/options
    #
    # Only exposes the property directory needed to choose a work location.
    def options
      @sites = Site.active.order(:name)
      @departments = Department.active.order(:name)
      render :options
    end

    # POST /public/employee_registrations
    def create
      email = registration_params[:email].to_s.strip.downcase
      existing = User.find_by(email: email)

      if existing.present?
        return render_existing_account_error(existing)
      end

      unless Site.active.exists?(id: registration_params[:current_site_id])
        return render_public_error(
          "invalid_site",
          "Select a valid work location to continue.",
          :unprocessable_entity
        )
      end

      if registration_params[:department_id].present? &&
         !Department.active.exists?(id: registration_params[:department_id])
        return render_public_error(
          "invalid_department",
          "Select a valid department to continue.",
          :unprocessable_entity
        )
      end

      if password_mismatch?
        return render_public_error(
          "password_mismatch",
          "Password and confirmation do not match.",
          :unprocessable_entity
        )
      end

      @user = User.new(registration_params)
      @user.email = email
      @user.user_type = "employee"
      @user.active = false
      @user.is_admin_approved = false
      @user.user_status = false
      @user.registration_status = "pending"
      @user.registration_submitted_at = Time.current
      @user.role = nil
      @user.created_by_id = nil

      if @user.save
        render :create, status: :created
      else
        render_public_error(
          "validation_failed",
          @user.errors.full_messages.to_sentence,
          :unprocessable_entity
        )
      end
    end

    private

    def registration_params
      @registration_params ||= params.require(:employee_registration).permit(
        :firstname, :lastname, :email, :mobile, :password, :password_confirmation,
        :current_site_id, :department_id, :position, :date_of_joining, :profile_image
      )
    end

    def password_mismatch?
      password = params.dig(:employee_registration, :password)
      confirmation = params.dig(:employee_registration, :password_confirmation)

      password.present? && password != confirmation
    end

    def render_existing_account_error(existing)
      if existing.pending_registration?
        render_public_error(
          "registration_pending",
          "This email already has a registration awaiting administrator approval.",
          :unprocessable_entity
        )
      elsif existing.rejected_registration?
        render_public_error(
          "registration_rejected",
          "This email was not approved. Please contact an administrator for help.",
          :unprocessable_entity
        )
      else
        render_public_error(
          "email_taken",
          "An account with this email already exists. Please sign in instead.",
          :unprocessable_entity
        )
      end
    end
  end
end
