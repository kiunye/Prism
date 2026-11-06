# frozen_string_literal: true

require "date"
require "time"

module Prism
  module Core
    class VariableInterpolator
      BOOLEANS = { "true" => true, "t" => true, "1" => true, "false" => false, "f" => false, "0" => false }.freeze

      TYPES = {
        string:   ->(v) { v.to_s },
        integer:  ->(v) { Integer(v) },
        float:    ->(v) { Float(v) },
        boolean:  ->(v) { BOOLEANS.fetch(v.to_s.downcase) { raise ArgumentError, "invalid boolean: #{v}" } },
        date:     ->(v) { Date.parse(v.to_s) },
        datetime: ->(v) { Time.parse(v.to_s) },
        uuid:     ->(v) { v.to_s },
      }.freeze

      def interpolate(sql, definitions, provided_values)
        param_index = 0
        params = {}

        param_sql = sql.gsub(/\{\{(\w+)\}\}/) do
          name = Regexp.last_match(1)
          definition = definitions.find { |d| d[:name].to_s == name }
          raise Prism::QueryError.new("Undefined variable: #{name}", code: :variable_missing) unless definition

          value = provided_values.fetch(name, definition[:default])
          raise Prism::QueryError.new("Missing required variable: #{name}", code: :variable_missing) if value.nil?

          begin
            value = TYPES.fetch(definition[:type].to_sym).call(value)
          rescue ArgumentError, TypeError, KeyError => e
            raise Prism::QueryError.new("Variable type error for #{name}: #{e.message}", code: :variable_type_error)
          end

          param_index += 1
          params["$#{param_index}"] = value
          "$#{param_index}"
        end

        [param_sql, params]
      end
    end
  end
end
