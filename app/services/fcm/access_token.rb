require "jwt"
require "json"
require "net/http"
require "uri"

module Fcm
  # Exchanges the Firebase service-account assertion for a Google OAuth2 access
  # token. The token is cached in-process and refreshed a minute before it
  # expires, so only one outbound OAuth request is made per process per hour.
  class AccessToken
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze
    TOKEN_LIFETIME = 3600
    EXPIRY_SKEW = 60

    @mutex = Mutex.new
    @token = nil
    @expires_at = nil

    class << self
      def fetch
        return @token if fresh?

        @mutex.synchronize do
          return @token if fresh?

          token, expires_in = request_token
          @token = token
          @expires_at = Time.current + expires_in.to_i
          token
        end
      end

      def reset!
        @mutex.synchronize do
          @token = nil
          @expires_at = nil
        end
      end

      private

      def fresh?
        @token.present? && @expires_at.present? && @expires_at > Time.current + EXPIRY_SKEW
      end

      def request_token
        credentials = Fcm::Configuration.credentials
        uri = URI.parse(credentials.fetch("token_uri"))
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(
          "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
          "assertion" => assertion(credentials)
        )

        response = http_for(uri).request(request)
        body = parse_body(response)

        unless response.is_a?(Net::HTTPSuccess)
          message = body["error_description"].presence || body["error"].presence || "HTTP #{response.code}"
          raise AuthenticationError, "Google OAuth token request failed: #{message}"
        end

        token = body["access_token"].to_s
        if token.blank?
          raise AuthenticationError, "Google OAuth token response did not include an access_token."
        end

        [ token, body["expires_in"].presence || TOKEN_LIFETIME ]
      rescue Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT,
             IOError, OpenSSL::SSL::SSLError, SocketError => e
        raise TransientError, "Could not reach Google OAuth: #{e.class}: #{e.message}"
      end

      def assertion(credentials)
        now = Time.current.to_i
        private_key = OpenSSL::PKey::RSA.new(credentials["private_key"])

        JWT.encode(
          {
            iss: credentials["client_email"],
            scope: SCOPE,
            aud: credentials["token_uri"],
            iat: now,
            exp: now + TOKEN_LIFETIME
          },
          private_key,
          "RS256",
          { kid: credentials["private_key_id"] }
        )
      rescue OpenSSL::PKey::PKeyError, OpenSSL::PKey::RSAError, JWT::EncodeError => e
        raise ConfigurationError, "Firebase private key is invalid: #{e.message}"
      end

      def http_for(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 10
        http.write_timeout = 10 if http.respond_to?(:write_timeout=)
        http
      end

      def parse_body(response)
        parsed = JSON.parse(response.body.to_s)
        parsed.is_a?(Hash) ? parsed : { "error_description" => "unexpected Google OAuth response" }
      rescue JSON::ParserError
        { "error_description" => "unparseable Google OAuth response" }
      end
    end
  end
end
