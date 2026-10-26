# Public, unauthenticated endpoints used by the visitor self-registration and
# QR check-in screens. These controllers intentionally bypass session/JWT
# authentication, so every action must be conservative about the data it
# exposes and the attributes it accepts.
class PublicController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :verify_authenticity_token

  before_action :force_json_format

  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  protected

  def render_public_error(code, message, status)
    render json: { error: { code: code, message: message } }, status: status
  end

  private

  def force_json_format
    request.format = :json
  end

  def render_bad_request(error)
    render_public_error("bad_request", error.message, :bad_request)
  end
end
