require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "prism_web"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = false
    config.root = File.expand_path("..", __dir__)
    config.secret_key_base = "test-only-secret"
    config.hosts.clear
  end
end
