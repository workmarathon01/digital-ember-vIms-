require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module LectAndNect
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # All timestamps are displayed in Indian Standard Time (UTC+05:30).
    # The database keeps storing UTC, so existing data stays valid and
    # timezone changes remain a display-only concern.
    config.time_zone = "Asia/Kolkata"
    config.active_record.default_timezone = :utc
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
