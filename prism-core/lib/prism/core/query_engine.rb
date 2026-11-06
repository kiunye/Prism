# frozen_string_literal: true

require "securerandom"
require "json"

module Prism
  module Core
    class QueryEngine
      def initialize(connection_manager:, validator: StatementValidator.new,
                     interpolator: VariableInterpolator.new, timeout: 30_000, max_rows: 10_000)
        @connection_manager = connection_manager
        @validator = validator
        @interpolator = interpolator
        @timeout = timeout
        @max_rows = max_rows
      end

      def execute(sql, variables: {}, values: {}, owner: nil, connection_slug: nil)
        param_sql, params = prepare(sql, variables, values)

        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        result = @connection_manager.with_connection(connection_slug) do |conn|
          conn.exec("BEGIN READ ONLY")
          conn.exec("SET LOCAL statement_timeout = #{@timeout}")
          conn.exec_params(param_sql, params.values)
        ensure
          conn.exec("COMMIT") rescue nil
        end

        duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000).round(2)

        rows = result.map do |row|
          row.transform_values { |v| v.nil? ? nil : v }
        end

        if rows.length > @max_rows
          raise Prism::QueryError.new(
            "Row limit exceeded (#{@max_rows})",
            code: :row_limit,
            sql_state: "54000"
          )
        end

        QueryResult.new(
          rows: rows,
          columns: result.fields,
          row_count: rows.length,
          duration_ms: duration,
          truncated: false,
          query_id: SecureRandom.uuid,
          connection_slug: connection_slug || @connection_manager.default_slug
        )
      rescue PG::QueryCanceled => e
        raise Prism::QueryError.new("Query timeout (#{@timeout}ms)", code: :timeout, sql_state: sql_state_of(e))
      rescue PG::InsufficientPrivilege => e
        raise Prism::QueryError.new("Read-only violation: #{e.message}", code: :statement_rejected, sql_state: sql_state_of(e))
      rescue PG::Error => e
        raise Prism::QueryError.new("Execution failed: #{e.message}", code: :execution_failed, sql_state: sql_state_of(e))
      end

      def validate(sql)
        @validator.validate(sql)
      end

      def explain(sql, variables: {}, values: {})
        param_sql, params = prepare(sql, variables, values)

        result = @connection_manager.with_connection do |conn|
          conn.exec_params("EXPLAIN (FORMAT JSON, ANALYZE false) #{param_sql}", params.values)
        end

        plan = JSON.parse(result[0]["QUERY PLAN"])
        ExplainResult.new(
          plan_json: plan,
          estimated_cost: plan.dig(0, "Plan", "Total Cost"),
          warnings: []
        )
      end

      private

      def prepare(sql, variables, values)
        definitions = variables.is_a?(Array) ? variables : []
        provided = values.empty? && variables.is_a?(Hash) ? variables : values
        param_sql, params = @interpolator.interpolate(sql, definitions, provided)

        validation = @validator.validate(param_sql)
        raise Prism::QueryError.new(validation.errors.first, code: :statement_rejected) unless validation.valid

        [param_sql, params]
      end

      def sql_state_of(error)
        error.result&.error_field(PG::Result::PG_DIAG_SQLSTATE)
      end
    end

    class QueryResult
      attr_reader :rows, :columns, :row_count, :duration_ms, :truncated, :query_id, :connection_slug

      def initialize(rows:, columns:, row_count:, duration_ms:, truncated:, query_id:, connection_slug:)
        @rows = rows
        @columns = columns
        @row_count = row_count
        @duration_ms = duration_ms
        @truncated = truncated
        @query_id = query_id
        @connection_slug = connection_slug
      end

      def each_row(&block)
        @rows.each(&block)
      end

      def to_csv(io = $stdout)
        require "csv"
        CSV(io) do |csv|
          csv << @columns
          @rows.each { |row| csv << @columns.map { |c| row[c] } }
        end
      end

      def to_a
        @rows
      end
    end

    class ExplainResult
      attr_reader :plan_json, :estimated_cost, :warnings

      def initialize(plan_json:, estimated_cost:, warnings:)
        @plan_json = plan_json
        @estimated_cost = estimated_cost
        @warnings = warnings
      end
    end
  end
end