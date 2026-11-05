require "json"

module Fcm
  # Lazily loads the Firebase service-account credentials. Nothing is read at
  # boot, so development and test environments work without the file; the first
  # push raises a clear ConfigurationError when credentials are actually needed.
  class Configuration
    ENV_JSON = "FIREBASE_CREDENTIALS_JSON".freeze
    ENV_PATH = "FIREBASE_CREDENTIALS_PATH".freeze
    ENV_PROJECT_ID = "FIREBASE_PROJECT_ID".freeze

    class << self
      def credentials
        @credentials ||= load_credentials
      end

      def project_id
        ENV[ENV_PROJECT_ID].presence ||
          credentials["project_id"].presence ||
          raise(ConfigurationError, "Firebase project_id is missing from the service-account JSON.")
      end

      def configured?
        credentials.present?
      rescue ConfigurationError
        false
      end

      # Useful in tests or after rotating the service-account file.
      def reset!
        @credentials = nil
      end

      private

      def load_credentials
        if ENV[ENV_JSON].present?
          parse(ENV[ENV_JSON], ENV_JSON)
        else
          path = ENV[ENV_PATH].presence || default_path
          unless File.exist?(path)
            raise ConfigurationError,
                  "Firebase credentials not found at #{path}. Set #{ENV_PATH} or #{ENV_JSON}."
          end

          parse(File.read(path), path)
        end
      end

      def default_path
        Rails.root.join("Notify", "visiTrack_Notify.json")
      end

      def parse(raw, source)
        data = JSON.parse(raw)
        required = %w[project_id private_key client_email token_uri]
        missing = required.select { |key| data[key].blank? }
        return data if missing.empty?

        raise ConfigurationError,
              "Firebase service-account JSON from #{source} is missing: #{missing.join(', ')}."
      rescue JSON::ParserError
        raise ConfigurationError, "Firebase credentials from #{source} are not valid JSON."
      end
    end
  end
end
