module Prism
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)

    class_option :mount_path, type: :string, default: "/prism",
                                desc: "Mount path for the PrismWeb engine"

    def create_initializer
      template "prism.rb", "config/initializers/prism.rb"
    end

    def create_secrets_directory
      empty_directory "secrets"
    end

    def update_gitignore
      append_to_file ".gitignore" do
        "# Prism secrets directory\nsecrets/\n"
      end
    end

    def mount_engine
      mount_path = options[:mount_path]
      mount_line = "mount PrismWeb::Engine => \"#{mount_path}\"\n"

      if File.exist?("config/routes.rb")
        routes = File.read("config/routes.rb")
        unless routes.include?(mount_line.strip)
          inject_into_file "config/routes.rb", mount_line, after: "Rails.application.routes.draw do\n"
        end
      else
        create_file "config/routes.rb", "Rails.application.routes.draw do\n#{mount_line}end\n"
      end
    end

    def run_migrations
      rake "prism:install:migrations"
    end

    def display_readme
      readme "INSTALLATION_README.md" if File.exist?(self.class.source_root.join("INSTALLATION_README.md"))
    end
  end
end