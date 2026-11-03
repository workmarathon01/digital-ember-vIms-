require "cgi"
require "net/http"
require "uri"

# Sends the visitor's public pass link by SMS after a pass is issued.
#
# The delivery gateway is intentionally configuration-driven so the same code
# works with any provider:
#
#   VISITOR_SMS_WEBHOOK_URL   POST JSON to a webhook that sends the SMS.
#   VISITOR_SMS_URL_TEMPLATE  GET a provider URL containing %{to} and %{message}
#                             placeholders (plus optional %{pass_url},
#                             %{pass_code} and %{visitor_id}).
#
# When neither is configured delivery is skipped and only a short log line is
# written (never the message itself, which contains a secret pass link).
class VisitorPassNotifier
  def initialize(visitor)
    @visitor = visitor
  end

  def deliver
    return false if visitor.contact_no.blank?

    if webhook_url.present?
      post_to_webhook
    elsif url_template.present?
      get_from_template
    else
      # Do not log the message itself: it contains a secret pass link.
      Rails.logger.info(
        "[VisitorPassNotifier] SMS gateway not configured; skipped SMS for visitor #{visitor.id}"
      )
    end

    true
  rescue StandardError => e
    Rails.logger.error(
      "[VisitorPassNotifier] Delivery failed for visitor #{visitor.id}: #{e.class}: #{e.message}"
    )
    false
  end

  def message
    parts = [
      "Dear #{visitor.name},",
      "your visitor pass #{visitor.pass_code} is ready.",
      "View your QR pass: #{visitor.public_pass_url}",
      "Valid from #{format_time(visitor.start_pass)} to #{format_time(visitor.end_pass)}."
    ]

    parts << "Host: #{visitor.host_name}." if visitor.host_name.present?
    parts << "Location: #{visitor.location_label}." if visitor.location_label.present?
    parts << "Do not share this link."

    parts.join(" ").squish
  end

  private

  attr_reader :visitor

  def webhook_url
    ENV["VISITOR_SMS_WEBHOOK_URL"].presence
  end

  def url_template
    ENV["VISITOR_SMS_URL_TEMPLATE"].presence
  end

  def post_to_webhook
    uri = URI.parse(webhook_url)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    if ENV["VISITOR_SMS_WEBHOOK_TOKEN"].present?
      request["Authorization"] = "Bearer #{ENV["VISITOR_SMS_WEBHOOK_TOKEN"]}"
    end
    request.body = {
      to: visitor.contact_no,
      message: message,
      template: "visitor_pass",
      visitor_id: visitor.id,
      pass_code: visitor.pass_code,
      pass_url: visitor.public_pass_url
    }.to_json

    perform_request(uri, request)
  end

  def get_from_template
    encoded_values = {
      "%{to}" => CGI.escape(visitor.contact_no.to_s),
      "%{message}" => CGI.escape(message),
      "%{pass_url}" => CGI.escape(visitor.public_pass_url.to_s),
      "%{pass_code}" => CGI.escape(visitor.pass_code.to_s),
      "%{visitor_id}" => visitor.id.to_s
    }
    url = encoded_values.reduce(url_template) do |template, (placeholder, value)|
      template.gsub(placeholder, value)
    end

    uri = URI.parse(url)
    perform_request(uri, Net::HTTP::Get.new(uri))
  end

  def perform_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 5

    response = http.request(request)
    return if response.is_a?(Net::HTTPSuccess)

    Rails.logger.warn(
      "[VisitorPassNotifier] Gateway returned #{response.code} for visitor #{visitor.id}"
    )
  end

  def format_time(value)
    return "—" if value.blank?

    value.in_time_zone.strftime("%d %b %Y, %I:%M %p")
  end
end
