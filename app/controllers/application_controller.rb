class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :load_current_user
  before_action :require_authentication
  helper_method :current_user, :authenticated?

  # JSON clients authenticate with a Bearer JWT, not cookies, so CSRF tokens
  # and origin checks do not apply to them.
  skip_before_action :verify_authenticity_token, if: :json_request?

  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden

  private

  def load_current_user
    Current.request_ip = request.remote_ip
    Current.user_agent = request.user_agent

    if json_request?
      load_user_from_jwt
    elsif session[:user_id]
      Current.user = User.active.find_by(id: session[:user_id])
    end
  end

  def json_request?
    request.format.json?
  end

  def load_user_from_jwt
    token = bearer_token
    return if token.blank?

    payload = JsonWebToken.decode_access(token)
    Current.user = User.active.find_by(id: payload["sub"])
  rescue JsonWebToken::ExpiredToken
    @jwt_error = :expired
  rescue JsonWebToken::InvalidToken
    @jwt_error = :invalid
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    header.start_with?("Bearer ") ? header.split(" ", 2).last : nil
  end

  def current_user
    Current.user
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication
    return if authenticated?

    if json_request?
      render_unauthorized
    else
      redirect_to new_session_path, alert: "Please sign in to continue."
    end
  end

  def render_unauthorized
    code, message =
      case @jwt_error
      when :expired then [ "token_expired", "Access token has expired. Refresh it and retry." ]
      when :invalid then [ "invalid_token", "Access token is invalid." ]
      else [ "unauthorized", "Authentication required. Provide a valid Bearer token." ]
      end

    response.set_header("WWW-Authenticate", "Bearer realm=\"lect_and_nect\", error=\"#{code}\"")
    render json: { error: { code: code, message: message } }, status: :unauthorized
  end

  def render_forbidden
    respond_to do |format|
      format.html { redirect_to root_path, alert: "You are not authorized to perform that action." }
      format.json { render json: { error: { code: "forbidden", message: "You are not authorized to perform that action." } }, status: :forbidden }
    end
  end
end
