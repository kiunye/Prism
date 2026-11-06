# frozen_string_literal: true

require "pg_query"

module Prism
  module Core
    class StatementValidator
      WRITE_NODES = %i[insert_stmt update_stmt delete_stmt merge_stmt].freeze

      def validate(sql)
        statements = PgQuery.parse(sql).tree.to_h[:stmts]

        return invalid("Multi-statement queries not allowed") unless statements.length == 1

        select = statements.first.dig(:stmt, :select_stmt)
        return invalid("Only SELECT statements allowed") unless select
        return invalid("SELECT INTO not allowed") if contains_key?(select, :into_clause)
        return invalid("Row locking not allowed") if contains_key?(select, :locking_clause)
        return invalid("Data-modifying statements not allowed") if WRITE_NODES.any? { |node| contains_key?(select, node) }

        ValidationResult.new(valid: true, errors: [], warnings: warnings_for(select))
      rescue PgQuery::ParseError => e
        invalid("SQL parse error: #{e.message}")
      end

      def check_keywords(sql)
        keywords = %w[INSERT UPDATE DELETE DROP CREATE ALTER TRUNCATE COPY GRANT REVOKE
                      BEGIN COMMIT ROLLBACK CALL DO PREPARE EXECUTE DEALLOCATE VACUUM
                      REINDEX CLUSTER LOCK UNLOCK]
        found = keywords.find { |kw| sql.match?(/\b#{kw}\b/i) }
        if found
          ValidationResult.new(valid: false, errors: ["Keyword #{found} not allowed"], warnings: [])
        else
          ValidationResult.new(valid: true, errors: [], warnings: [])
        end
      end

      private

      def warnings_for(select)
        warnings = []
        warnings << "Consider adding LIMIT clause" unless select.key?(:limit_count)
        warnings << "SELECT * may return unexpected columns" if select_star?(select)
        warnings
      end

      def select_star?(select)
        Array(select[:target_list]).any? do |target|
          fields = target.dig(:res_target, :val, :column_ref, :fields)
          Array(fields).any? { |field| field.key?(:a_star) }
        end
      end

      def contains_key?(node, key)
        case node
        when Hash then node.key?(key) || node.each_value.any? { |value| contains_key?(value, key) }
        when Array then node.any? { |value| contains_key?(value, key) }
        else false
        end
      end

      def invalid(message)
        ValidationResult.new(valid: false, errors: [message], warnings: [])
      end
    end

    class ValidationResult
      attr_reader :valid, :errors, :warnings

      def initialize(valid:, errors:, warnings:)
        @valid = valid
        @errors = errors
        @warnings = warnings
      end
    end
  end
end
