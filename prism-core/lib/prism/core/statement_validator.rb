# frozen_string_literal: true

require "pg_query"

module Prism
  module Core
    class StatementValidator
      FORBIDDEN_TYPES = %i[
        insert_stmt update_stmt delete_stmt create_stmt drop_stmt alter_stmt
        truncate_stmt copy_stmt grant_stmt revoke_stmt prepare_stmt execute_stmt
        deallocate_stmt transaction_stmt lock_stmt vacuum_stmt analyze_stmt
        reindex_stmt cluster_stmt call_stmt do_stmt
      ].freeze

      def validate(sql)
        parse_tree = PgQuery.parse(sql)

        return invalid("Multi-statement queries not allowed") if parse_tree.stmts.length != 1

        stmt = parse_tree.stmts.first
        node = stmt.stmt

        return invalid("Only SELECT statements allowed") unless select_or_with_select?(node)

        return invalid("Data-modifying CTEs not allowed") if has_modifying_cte?(node)

        return invalid("Function calls with side effects not allowed") if has_procedure_call?(node)

        warnings = []
        warnings << "Consider adding LIMIT clause" unless has_limit?(node)
        warnings << "SELECT * may return unexpected columns" if select_star?(node)

        ValidationResult.new(valid: true, errors: [], warnings: warnings)
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

      def select_or_with_select?(node)
        return true if node.respond_to?(:select_stmt) && node.select_stmt

        if node.respond_to?(:with_clause) && node.with_clause
          ctes = node.with_clause.ctes
          return ctes.all? { |cte| cte.stmt&.select_stmt }
        end

        false
      end

      def has_modifying_cte?(node)
        return false unless node.respond_to?(:with_clause) && node.with_clause

        node.with_clause.ctes.any? do |cte|
          cte.stmt && !cte.stmt.select_stmt
        end
      end

      def has_procedure_call?(node)
        walk(node) do |n|
          return true if n.respond_to?(:node_tag) && n.node_tag == :T_CallStmt
          return true if n.respond_to?(:node_tag) && n.node_tag == :T_DoStmt
        end
        false
      end

      def has_limit?(node)
        return true if node.respond_to?(:limit_count) && node.limit_count

        if node.respond_to?(:with_clause) && node.with_clause
          return node.with_clause.ctes.any? { |cte| has_limit?(cte.stmt) if cte.stmt }
        end

        false
      end

      def select_star?(node)
        return false unless node.respond_to?(:target_list)

        node.target_list&.any? do |target|
          target.respond_to?(:res_target) && target.res_target&.val&.respond_to?(:column_ref) &&
            target.res_target.val.column_ref&.fields&.any? { |f| f.string&.str == "*" }
        end
      end

      def walk(node, &block)
        return unless node

        yield node

        node.instance_variables.each do |var|
          val = node.instance_variable_get(var)
          case val
          when PgQuery::Nodes::Node
            walk(val, &block)
          when Array
            val.each { |v| walk(v, &block) if v.is_a?(PgQuery::Nodes::Node) }
          end
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