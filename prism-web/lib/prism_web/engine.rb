module PrismWeb
  def self.table_name_prefix
    "prism_"
  end

  class Engine < ::Rails::Engine
    isolate_namespace PrismWeb

    config.generators do |generator|
      generator.helper nil
      generator.assets false
      generator.stylesheets false
      generator.javascripts false
    end
  end
end
