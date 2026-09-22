class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: %i[new create refresh]
  before_action :clear_existing_session, only: :new

  def new
    redirect_to root_path if authenticated?
  end

  def create
    user = User.active.find_by(email: params[:email].to_s.strip.downcase)

    if user.nil?
      return failed_attempt
    end

    if user.locked_out?
      message = "Account locked. Try again after #{user.locked_at + User::LOCKOUT_DURATION}."
      respond_to do |format|
        format.html { redirect_to new_session_path, alert: message }
        format.json { render json: { error: { code: "account_locked", message: message } }, status: :locked }
      end
      return
    end

    if user.authenticate(params[:password])
      authenticate_user(user)
    else
      user.register_failed_login!
      failed_attempt(user)
    end
  end

  def refresh
    token = params[:refresh_token].presence || bearer_token
    payload = JsonWebToken.decode_refresh(token)
    user = User.active.find_by(id: payload["sub"])

    return render_token_error("invalid_token", "Refresh token is no longer valid.") if user.nil?

    issue_tokens(user)
  rescue JsonWebToken::ExpiredToken
    render_token_error("token_expired", "Refresh token has expired. Please sign in again.")
  rescue JsonWebToken::InvalidToken
    render_token_error("invalid_token", "Refresh token is invalid.")
  end

  def destroy
    audit_sign_out
    reset_session

    respond_to do |format|
      format.html { redirect_to new_session_path, notice: "Signed out successfully." }
      format.json { render json: { message: "Signed out successfully." }, status: :ok }
    end
  end

  private

  def authenticate_user(user)
    user.record_login!(request)
    AuditLog.create!(actor: user, action: "sign_in", resource_type: "User", resource_id: user.id,
                     ip_address: request.remote_ip, user_agent: request.user_agent)

    if request.format.json?
      issue_tokens(user)
    else
      reset_session
      session[:user_id] = user.id
      redirect_to root_path, notice: "Signed in successfully. Welcome, #{user.full_name}."
    end
  end

  def issue_tokens(user)
    @user = user
    @access_token = JsonWebToken.encode_access(user)
    @refresh_token = JsonWebToken.encode_refresh(user)
    @expires_in = JsonWebToken.access_ttl
    render :token, status: :ok
  end

  def render_token_error(code, message)
    response.set_header("WWW-Authenticate", "Bearer realm=\"lect_and_nect\", error=\"#{code}\"")
    render json: { error: { code: code, message: message } }, status: :unauthorized
  end

  def failed_attempt(user = nil)
    message = user.nil? ? "Invalid email or password." : "Invalid password. #{User::MAX_FAILED_ATTEMPTS - user.failed_attempts} attempts remaining."

    respond_to do |format|
      format.html do
        flash.now[:alert] = message
        render :new, status: :unprocessable_entity
      end
      format.json { render json: { error: { code: "invalid_credentials", message: message } }, status: :unauthorized }
    end
  end

  def audit_sign_out
    return if Current.user.blank?

    AuditLog.create!(actor: Current.user, action: "sign_out", resource_type: "User", resource_id: Current.user.id,
                     ip_address: request.remote_ip, user_agent: request.user_agent)
  end

  def clear_existing_session
    reset_session if session[:user_id]
  end
end
