# frozen_string_literal: true

require "pg"

module Prism
  module Core
    class ConnectionManager
      def initialize(config)
        @config = config
        @pools = {}
      end

      def pool(slug)
        @pools[slug] ||= build_pool(@config.connections[slug])
      end

      def with_connection(slug = nil)
        slug ||= @config.connections.default_slug
        pool(slug).with_connection { |conn| yield conn }
      end

      private

      def build_pool(conn_config)
        if conn_config.reuse_host_pool?
          HostPoolWrapper.new(ActiveRecord::Base.connection_pool, read_only_role: conn_config.read_only_role)
        else
          creds = CredentialsLoader.load(conn_config.credentials_file)
          IndependentPool.new(
            host: creds[:host] || "localhost",
            port: creds[:port] || 5432,
            dbname: creds[:database] || creds[:dbname],
            user: creds[:username] || creds[:user],
            password: creds[:password],
            pool_size: conn_config.pool_size || 5,
            read_only_role: conn_config.read_only_role,
            statement_timeout: (conn_config.statement_timeout || 30) * 1000,
            application_name: "prism_#{conn_config.slug}"
          )
        end
      end
    end

    class HostPoolWrapper
      def initialize(ar_pool, read_only_role:)
        @ar_pool = ar_pool
        @read_only_role = read_only_role
      end

      def with_connection
        @ar_pool.with_connection do |ar_conn|
          raw = ar_conn.raw_connection
          raw.exec("SET ROLE #{@read_only_role}")
          yield raw
        ensure
          raw.exec("RESET ROLE") if raw
        end
      end
    end

    class IndependentPool
      def initialize(host:, port:, dbname:, user:, password:, pool_size:, read_only_role:, statement_timeout:, application_name:)
        @pool = PG::ConnectionPool.new(
          dbname: dbname,
          host: host,
          port: port,
          user: user,
          password: password,
          max_connections: pool_size,
          options: "-c default_transaction_read_only=on " \
                   "-c statement_timeout=#{statement_timeout} " \
                   "-c application_name=#{application_name}"
        )
      end

      def with_connection
        @pool.with_connection { |conn| yield conn }
      end
    end
  end
end