module PrismWeb
  class Engine < ::Rails::Engine
    isolate_namespace PrismWeb

    config.before_initialize do |app|
      app.config.assets.paths << root.join("vendor", "assets", "stylesheets")

      if Prism.const_defined?(:VERSION) && self.const_defined?(:VERSION)
        Rails.logger.info "[PRISM] Loading prism-web v#{VERSION} with prism-core v#{Prism::VERSION}"
      end
    end

    config.generators do |generator|
      generator.helper nil
      generator.assets false
      generator.stylesheets false
      generator.javascripts false
    end

    config.after_initialize do |app|
      Rails.logger.info "[PRISM] Engine ready at /prism"
    end

    initializer "prism_web.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include PrismWeb::EngineHelpers
      end
    end

    class << self
      def migrate(command = :up)
        path = File.expand_path(
          "../../../../../db/migrate",
          __dir__
        )
        Rake::Task["db:migrate"].invoke
        Rake::Task["db:structure:dump"].invoke if command == :dump
      end
    end
  end

  module EngineHelpers
    def prism_engine_root
      PrismWeb::Engine.root
    end

    def prism_enabled?
      defined?(::Prism) && Prism.config.present?
    end
  end
end