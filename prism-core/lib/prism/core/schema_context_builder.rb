# frozen_string_literal: true

module Prism
  module Core
    class SchemaContextBuilder
      def initialize(connection_manager, visibility_config)
        @inspector = SchemaInspector.new(connection_manager, visibility_config)
      end

      def build(connection_slug, token_budget: 8000)
        raw = build_raw(connection_slug)
        truncate_to_token_budget(raw, token_budget)
      end

      def build_raw(connection_slug)
        tables = @inspector.tables(connection_slug)
        return "No tables visible." if tables.empty?

        tables_data = tables.map do |table|
          {
            table: table,
            columns: @inspector.columns(connection_slug, table),
            primary_key: @inspector.columns(connection_slug, table).select { |c| c[:primary_key] }.map { |c| c[:name] },
            sample: @inspector.sample_rows(connection_slug, table)
          }
        end

        fks = @inspector.foreign_keys(connection_slug, tables)

        render_context(tables_data, fks)
      end

      private

      def render_context(tables_data, relationships)
        lines = []
        lines << "DATABASE SCHEMA"
        lines << "=" * 40
        lines << ""

        tables_data.each do |td|
          lines << "TABLE #{td[:table].upcase}"
          lines << "-" * (td[:table].length + 6)

          td[:columns].each do |col|
            pk_marker = td[:primary_key].include?(col[:name]) ? " 🔑" : ""
            type = format_type(col)
            nullable = col[:nullable] ? "" : " NOT NULL"
            lines << "  #{col[:name]}: #{type}#{nullable}#{pk_marker}"
          end

          if td[:sample].any?
            lines << "  -- SAMPLE"
            sample_cols = td[:columns].first(5).map { |c| c[:name] }
            td[:sample].first(2).each do |row|
              vals = sample_cols.map { |c| format_sample_value(row[c]) }
              lines << "  --   #{vals.join(" | ")}"
            end
          end

          lines << ""
        end

        if relationships.any?
          lines << "RELATIONSHIPS"
          lines << "=" * 14
          lines << ""
          relationships.each do |rel|
            lines << "  #{rel['from_table']}.#{rel['from_column']} → #{rel['to_table']}.#{rel['to_column']}"
          end
        end

        lines.join("\n")
      end

      def format_type(col)
        case col[:data_type]
        when "character varying" then "varchar(#{col[:char_max_len]})"
        when "numeric" then "numeric(#{col[:num_precision]},#{col[:num_scale]})"
        else col[:data_type]
        end
      end

      def format_sample_value(val)
        case val
        when nil then "NULL"
        when String then val.length > 50 ? "\"#{val[0..47]}...\"" : "\"#{val}\""
        when Time, Date, DateTime then val.iso8601
        else val.to_s
        end
      end

      def truncate_to_token_budget(text, budget)
        max_chars = budget * 4
        return text if text.length <= max_chars

        truncated = text
        truncated = drop_samples(truncated) while truncated.length > max_chars
        truncated = drop_column_details(truncated) while truncated.length > max_chars
        truncated = drop_relationships(truncated) while truncated.length > max_chars
        truncated = drop_tables(truncated) while truncated.length > max_chars
        truncated
      end

      def drop_samples(text)
        text.gsub(/  -- SAMPLE\n(  --   .*\n)+/, "")
      end

      def drop_column_details(text)
        text.gsub(/  \w+: \w+(\([\d,]+\))? ?(NOT NULL)? ?🔑?\n/, "  ...\n")
      end

      def drop_relationships(text)
        text.gsub(/RELATIONSHIPS\n={14}\n\n(  .*\n)*/, "")
      end

      def drop_tables(text)
        tables = text.split("TABLE ").drop(1)
        return text if tables.empty?
        "DATABASE SCHEMA\n#{"=" * 40}\n\n[truncated: #{tables.length} more tables]\n"
      end
    end
  end
end