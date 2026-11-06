# frozen_string_literal: true

require "active_support/cache"

module Prism
  module Core
    class SchemaInspector
      def initialize(connection_manager, visibility_config, cache: nil)
        @connections = connection_manager
        @visibility = visibility_config
        @cache = cache || SchemaCache.new
      end

      def tables(connection_slug, owner: nil)
        @cache.fetch("tables:#{connection_slug}:#{owner_cache_key(owner)}", expires_in: 1.hour) do
          @connections.with_connection(connection_slug) do |conn|
            result = conn.exec_params(<<~SQL)
              SELECT table_name
              FROM information_schema.tables
              WHERE table_schema = 'public'
                AND table_type = 'BASE TABLE'
            SQL
            all_tables = result.to_a.map { |r| r["table_name"] }
            @visibility.filter(connection_slug, owner, all_tables)
          end
        end
      end

      def columns(connection_slug, table_name, owner: nil)
        @cache.fetch("columns:#{connection_slug}:#{table_name}", expires_in: 1.hour) do
          @connections.with_connection(connection_slug) do |conn|
            cols = conn.exec_params(<<~SQL, [table_name]).to_a
              SELECT column_name, data_type, is_nullable, column_default,
                     character_maximum_length, numeric_precision, numeric_scale
              FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = $1
              ORDER BY ordinal_position
            SQL

            pks = conn.exec_params(<<~SQL, [table_name]).to_a
              SELECT kcu.column_name
              FROM information_schema.table_constraints tc
              JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
              WHERE tc.table_schema = 'public'
                AND tc.table_name = $1
                AND tc.constraint_type = 'PRIMARY KEY'
            SQL
            pk_names = pks.map { |r| r["column_name"] }.to_set

            cols.map do |c|
              {
                name: c["column_name"],
                data_type: c["data_type"],
                nullable: c["is_nullable"] == "YES",
                default: c["column_default"],
                primary_key: pk_names.include?(c["column_name"]),
                char_max_len: c["character_maximum_length"],
                num_precision: c["numeric_precision"],
                num_scale: c["numeric_scale"]
              }
            end
          end
        end
      end

      def indexes(connection_slug, table_name, owner: nil)
        @cache.fetch("indexes:#{connection_slug}:#{table_name}", expires_in: 1.hour) do
          @connections.with_connection(connection_slug) do |conn|
            conn.exec_params(<<~SQL, [table_name]).to_a
              SELECT
                i.relname AS index_name,
                a.attname AS column_name,
                am.amname AS index_type,
                idx.indisunique AS is_unique,
                idx.indisprimary AS is_primary
              FROM pg_index idx
              JOIN pg_class c ON c.oid = idx.indrelid
              JOIN pg_class i ON i.oid = idx.indexrelid
              JOIN pg_am am ON am.oid = i.relam
              JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(idx.indkey)
              WHERE c.relname = $1
              ORDER BY i.relname, a.attnum
            SQL
          end.map do |r|
            {
              name: r["index_name"],
              column: r["column_name"],
              type: r["index_type"],
              unique: r["is_unique"] == "t" || r["is_unique"] == true,
              primary: r["is_primary"] == "t" || r["is_primary"] == true
            }
          end
        end
      end

      def foreign_keys(connection_slug, tables, owner: nil)
        return [] if tables.empty?

        placeholders = tables.map { |t| "'#{t.gsub("'", "''")}'" }.join(",")

        @cache.fetch("fks:#{connection_slug}:#{tables.sort.join(",")}", expires_in: 1.hour) do
          @connections.with_connection(connection_slug) do |conn|
            conn.exec_params(<<~SQL).to_a
              SELECT
                tc.table_name AS from_table,
                kcu.column_name AS from_column,
                ccu.table_name AS to_table,
                ccu.column_name AS to_column
              FROM information_schema.table_constraints tc
              JOIN information_schema.key_column_usage kcu
                ON tc.constraint_name = kcu.constraint_name
              JOIN information_schema.constraint_column_usage ccu
                ON tc.constraint_name = ccu.constraint_name
              WHERE tc.table_schema = 'public'
                AND tc.constraint_type = 'FOREIGN KEY'
                AND tc.table_name IN (#{placeholders})
                AND ccu.table_name IN (#{placeholders})
            SQL
          end
        end
      end

      def sample_rows(connection_slug, table_name, limit: 3, max_columns: 5, owner: nil)
        @connections.with_connection(connection_slug) do |conn|
          cols = conn.exec_params("SELECT * FROM #{conn.quote_ident(table_name)} LIMIT 0").fields
          selected_cols = cols.first(max_columns)
          return [] if selected_cols.empty?

          conn.exec_params(<<~SQL).to_a
            SELECT #{selected_cols.map { |c| conn.quote_ident(c) }.join(", ")}
            FROM #{conn.quote_ident(table_name)}
            LIMIT #{limit}
          SQL
        end
      end

      private

      def owner_cache_key(owner)
        return "anon" if owner.nil?
        "#{owner[:type]}_#{owner[:id]}"
      end
    end

    class SchemaCache
      def initialize(store: nil, default_ttl: 1.hour)
        @store = store || ActiveSupport::Cache::MemoryStore.new(size: 32.megabytes)
        @default_ttl = default_ttl
      end

      def fetch(key, expires_in: @default_ttl, &block)
        @store.fetch(key, expires_in: expires_in, &block)
      end

      def invalidate(connection_slug)
        @store.delete_matched("tables:#{connection_slug}")
        @store.delete_matched("columns:#{connection_slug}:*")
        @store.delete_matched("fks:#{connection_slug}:*")
      end

      def on_migration_completed(connection_slug)
        invalidate(connection_slug)
      end
    end
  end
end