# frozen_string_literal: true

require "yaml"

module Prism
  module Core
    class CredentialsLoader
      def self.load(filepath)
        path = Pathname.new(filepath)
        raise "Credentials file not found: #{filepath}" unless path.exist?

        mode = path.stat.mode & 0777
        raise "Credentials file permissions too open: #{mode.to_s(8)} (expected 0400)" unless mode == 0400

        YAML.load_file(path).transform_keys(&:to_sym)
      end
    end
  end
end