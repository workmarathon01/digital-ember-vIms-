require "cgi"
require "json"
require "net/http"

module Fcm
  # Minimal, dependency-free Firebase Cloud Messaging HTTP v1 client.
  #
  # FCM v1 has no batch endpoint, so `deliver_each` keeps one keep-alive
  # connection per worker thread and fans out across a small bounded pool. For
  # the common case (a user with 1-5 devices) this is a single TLS handshake per
  # worker and one HTTPS request per token.
  class Client
    HOST = "fcm.googleapis.com".freeze
    PORT = 443
    DEFAULT_CONCURRENCY = 8
    MAX_CONCURRENCY = 16
    DEFAULT_MAX_RETRIES = 2
    RETRYABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze
    RETRYABLE_ERRORS = [
      EOFError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      Errno::EPIPE,
      Errno::ETIMEDOUT,
      IOError,
      Net::HTTPBadResponse,
      Net::HTTPHeaderSyntaxError,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::WriteTimeout,
      OpenSSL::SSL::SSLError,
      SocketError,
      Timeout::Error
    ].freeze

    def initialize(access_token: nil, concurrency: nil, max_retries: nil)
      @access_token = access_token
      @concurrency = clamp_concurrency(concurrency || ENV.fetch("FCM_MAX_CONCURRENCY", DEFAULT_CONCURRENCY))
      @max_retries = (max_retries || ENV.fetch("FCM_MAX_RETRIES", DEFAULT_MAX_RETRIES)).to_i.clamp(0, 5)
    end

    # Sends one message. Exactly one target (token, topic or condition) is
    # required. Returns an Fcm::Result; provider errors are not raised so the
    # caller can inspect and clean up tokens.
    def deliver(token: nil, topic: nil, condition: nil, payload: {})
      targets = [ token, topic, condition ].compact.reject { |value| value.to_s.strip.empty? }
      raise ArgumentError, "provide exactly one of token, topic or condition" unless targets.size == 1

      connection = Connection.new
      post_message(connection, token.presence, payload, topic: topic.presence, condition: condition.presence)
    ensure
      connection&.close
    end

    # Sends the same payload to many registration tokens concurrently. Results
    # are returned in completion order.
    def deliver_each(tokens:, payload: {})
      tokens = Array(tokens).map { |token| token.to_s.strip }.reject(&:blank?).uniq
      return [] if tokens.empty?

      # Fail fast on missing/bad credentials before spawning threads, and warm
      # the OAuth token so workers share one cached value.
      access_token

      queue = Queue.new
      tokens.each { |token| queue << token }

      results = []
      lock = Mutex.new
      worker_count = [ @concurrency, tokens.size ].min

      workers = Array.new(worker_count) do
        Thread.new do
          Rails.application.executor.wrap do
            connection = Connection.new
            begin
              loop do
                token = queue.pop(true)
                result = post_message(connection, token, payload)
                lock.synchronize { results << result }
              end
            rescue ThreadError
              # Queue drained.
            rescue Fcm::Error
              # Credential/config problems are not per-token failures. Let the
              # job/controller see them.
              raise
            rescue StandardError => e
              Rails.logger.error("[Fcm::Client] worker error: #{e.class}: #{e.message}")
              drain_failed(queue, lock, results, e)
            ensure
              connection.close
            end
          end
        end
      end

      thread_error = nil
      workers.each do |worker|
        worker.join
      rescue Fcm::Error => e
        thread_error ||= e
      end
      raise thread_error if thread_error

      results
    end

    private

    def post_message(connection, token, payload, topic: nil, condition: nil)
      body = build_body(token: token, topic: topic, condition: condition, payload: payload)
      attempts = 0

      loop do
        begin
          response = connection.request(build_request(body))
          status = response.code.to_i

          # Access tokens can be revoked or a worker clock can drift. Refresh
          # once before treating 401 as a real failure.
          if status == 401 && attempts < @max_retries
            Fcm::AccessToken.reset!
            @access_token = nil
            attempts += 1
            next
          end

          if RETRYABLE_STATUSES.include?(status) && attempts < @max_retries
            attempts += 1
            sleep(backoff_seconds(attempts, response))
            next
          end

          return parse_response(token, response)
        rescue *RETRYABLE_ERRORS => e
          connection.close
          attempts += 1
          if attempts <= @max_retries
            sleep(backoff_seconds(attempts))
            next
          end

          return Result.new(
            token: token,
            success: false,
            error_code: "NETWORK_ERROR",
            error_message: "#{e.class}: #{e.message}"
          )
        end
      end
    end

    def build_request(body)
      request = Net::HTTP::Post.new(message_path)
      request["Authorization"] = "Bearer #{access_token}"
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = body
      request
    end

    def build_body(token:, topic:, condition:, payload:)
      unless payload.nil? || payload.is_a?(Hash)
        raise ArgumentError, "payload must be a Hash"
      end

      message = (payload || {}).deep_stringify_keys
      # Never allow a caller to override the target.
      message.delete("token")
      message.delete("topic")
      message.delete("condition")
      message["token"] = token if token.present?
      message["topic"] = topic if topic.present?
      message["condition"] = condition if condition.present?

      { "message" => message }.to_json
    end

    def parse_response(token, response)
      status = response.code.to_i
      body = parse_json(response.body)

      if response.is_a?(Net::HTTPSuccess)
        return Result.new(token: token, success: true, message_id: body["name"], http_status: status)
      end

      error = body["error"] || {}
      details = Array(error["details"])
      fcm_error = details.find { |detail| detail.is_a?(Hash) && detail["errorCode"].present? }
      error_code = fcm_error&.fetch("errorCode", nil).presence ||
                   error["status"].presence ||
                   "HTTP_#{status}"

      Rails.logger.warn("[Fcm::Client] delivery failed status=#{status} code=#{error_code}")

      Result.new(
        token: token,
        success: false,
        error_code: error_code,
        error_status: error["status"],
        error_message: error["message"],
        http_status: status
      )
    end

    def parse_json(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      {}
    end

    def access_token
      @access_token ||= Fcm::AccessToken.fetch
    end

    def message_path
      @message_path ||= "/v1/projects/#{CGI.escape(Fcm::Configuration.project_id)}/messages:send"
    end

    def backoff_seconds(attempt, response = nil)
      retry_after = response&.[]("Retry-After").to_i
      base = retry_after.positive? ? retry_after.to_f : (2**(attempt - 1)).to_f
      [ base, 5.0 ].min + (rand * 0.25)
    end

    def clamp_concurrency(value)
      value.to_i.clamp(1, MAX_CONCURRENCY)
    end

    def drain_failed(queue, lock, results, error)
      loop do
        token = queue.pop(true)
        lock.synchronize do
          results << Result.new(
            token: token,
            success: false,
            error_code: "CLIENT_ERROR",
            error_message: "#{error.class}: #{error.message}"
          )
        end
      end
    rescue ThreadError
      nil
    end

    # A tiny per-thread keep-alive wrapper. Net::HTTP objects are not
    # thread-safe, so each worker owns exactly one.
    class Connection
      def request(request)
        start unless started?
        @http.request(request)
      end

      def close
        @http.finish if @http&.started?
      rescue StandardError
        # Closing a broken keep-alive socket must never mask the real error.
        nil
      ensure
        @http = nil
      end

      private

      def started?
        @http&.started?
      end

      def start
        @http ||= Net::HTTP.new(HOST, PORT)
        configure(@http)
        @http.start
      end

      def configure(http)
        http.use_ssl = true
        http.open_timeout = 5
        http.read_timeout = 10
        http.write_timeout = 10 if http.respond_to?(:write_timeout=)
        http.keep_alive_timeout = 30 if http.respond_to?(:keep_alive_timeout=)
      end
    end
  end
end
