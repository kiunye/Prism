# frozen_string_literal: true

module Prism
  module Core
    class VariableInterpolator
      TYPES = {
        string:   ->(v) { v.to_s },
        integer:  ->(v) { Integer(v) },
        float:    ->(v) { Float(v) },
        boolean:  ->(v) { ActiveModel::Type::Boolean.new.cast(v) },
        date:     ->(v) { Date.parse(v.to_s) },
        datetime: ->(v) { Time.zone.parse(v.to_s) },
        uuid:     ->(v) { v.to_s },
      }.freeze

      def interpolate(sql, definitions, provided_values)
        param_index = 0
        params = {}

        param_sql = sql.gsub(/\{\{(\w+)\}\}/) do |_match, name|
          definition = definitions.find { |d| d[:name] == name }
          raise Prism::QueryError.new("Undefined variable: #{name}", code: :variable_missing) unless definition

          value = provided_values.fetch(name, definition[:default])
          raise Prism::QueryError.new("Missing required variable: #{name}", code: :variable_missing) if value.nil?

          begin
            value = TYPES[definition[:type]].call(value)
          rescue ArgumentError, TypeError => e
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