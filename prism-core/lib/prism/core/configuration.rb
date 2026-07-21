# frozen_string_literal: true

module Prism
  class Configuration
    attr_reader :owner_resolver, :auth_guard, :middleware
    attr_reader :connections, :visibility, :query, :cache, :ai, :dashboard, :sharing, :secrets

    def self.configure(&block)
      new.tap { |c| c.instance_eval(&block) }.freeze
    end

    def initialize
      @connections = ConnectionRegistry.new
      @visibility = VisibilityConfig.new
      @query = QueryConfig.new
      @cache = CacheConfig.new
      @ai = AIConfig.new
      @dashboard = DashboardConfig.new
      @sharing = SharingConfig.new
      @secrets = SecretsConfig.new
      @middleware = MiddlewareStack.new
      set_defaults
    end

    def owner_resolver=(proc)
      @owner_resolver = proc
    end

    def auth_guard=(proc)
      @auth_guard = proc
    end

    def connection(slug, &block)
      @connections.register(slug, &block)
    end

    def validate!
      errors = []
      errors << "owner_resolver required" unless @owner_resolver
      errors << "auth_guard required" unless @auth_guard
      errors << "no connections defined" if @connections.empty?
      errors << "no default connection" unless @connections.default
      @connections.each { |c| errors.concat(c.validate!) }
      errors.concat(@visibility.validate!)
      errors.concat(@query.validate!)
      errors.concat(@ai.validate!) if @ai.enabled
      raise ConfigurationError, errors.join("; ") if errors.any?
    end

    private

    def set_defaults
      @query.max_rows ||= 10_000
      @query.timeout ||= 30
      @query.rate_limit ||= 60
      @query.statement_timeout ||= 30
      @query.enable_explain = true if @query.enable_explain.nil?
      @dashboard.min_refresh_interval ||= 30
      @dashboard.max_widgets ||= 50
      @dashboard.default_theme ||= :dark
      @dashboard.grid_columns ||= 12
      @sharing.token_length ||= 32
      @sharing.default_expiry ||= 30 * 24 * 60 * 60
      @sharing.max_expiry ||= 365 * 24 * 60 * 60
      @secrets.directory ||= Pathname.new("secrets")
    end
  end

  class ConnectionRegistry
    include Enumerable

    def initialize
      @connections = {}
    end

    def register(slug, &block)
      config = ConnectionConfig.new(slug)
      config.instance_eval(&block) if block
      @connections[slug] = config
    end

    def [](slug)
      @connections[slug]
    end

    def each(&block)
      @connections.values.each(&block)
    end

    def empty?
      @connections.empty?
    end

    def default
      @connections.values.find(&:default?)
    end

    def default_slug
      default&.slug&.to_s
    end
  end

  class ConnectionConfig
    attr_accessor :slug, :name, :adapter, :reuse_host_pool, :credentials_file,
                  :read_only_role, :default, :pool_size, :statement_timeout

    def initialize(slug)
      @slug = slug
      @adapter = :postgresql
      @default = false
    end

    def default?
      @default
    end

    def validate!
      errors = []
      errors << "slug required" unless slug
      errors << "read_only_role required" unless read_only_role
      errors << "credentials_file required" unless reuse_host_pool || credentials_file
      errors
    end
  end

  class VisibilityConfig
    attr_accessor :mode, :allowlist, :denylist, :resolver

    MODES = %i[allowlist denylist dynamic].freeze

    SYSTEM_DENYLIST = %w[
      schema_migrations ar_internal_metadata
      solid_queue_jobs solid_queue_processes solid_queue_ready
      solid_cache_entries solid_cable_messages
      prism_dashboards prism_widgets prism_saved_queries
      prism_ai_conversations prism_share_tokens prism_query_cache
      information_schema_tables information_schema_columns
      pg_catalog pg_class pg_attribute pg_index pg_constraint
    ].to_set.freeze

    def initialize
      @mode = :allowlist
      @allowlist = Set.new
      @denylist = SYSTEM_DENYLIST.dup
      @resolver = nil
    end

    def allowed_tables(connection_slug, owner)
      tables = case mode
               when :allowlist then @allowlist
               when :denylist  then all_tables(connection_slug) - @denylist
               when :dynamic   then @resolver.call(connection_slug, owner)
               end
      (tables - SYSTEM_DENYLIST).sort
    end

    def validate!
      errors = []
      errors << "invalid visibility mode" unless MODES.include?(mode)
      errors << "dynamic mode requires resolver" if mode == :dynamic && !resolver
      errors
    end

    private

    def all_tables(connection_slug)
      # This will be populated by SchemaInspector
      []
    end
  end

  class QueryConfig
    attr_accessor :max_rows, :timeout, :rate_limit, :statement_timeout, :enable_explain

    def validate!
      errors = []
      errors << "max_rows must be positive" if max_rows && max_rows <= 0
      errors << "timeout must be positive" if timeout && timeout <= 0
      errors << "rate_limit must be positive" if rate_limit && rate_limit <= 0
      errors
    end
  end

  class CacheConfig
    attr_accessor :ttl_profiles

    def initialize
      @ttl_profiles = {
        dashboard_widget: 30,
        schema: 3600,
        ai_context: 600,
        query_result: 60,
      }
    end
  end

  class AIConfig
    attr_accessor :enabled, :provider, :model, :api_key_file, :max_tokens,
                  :temperature, :system_prompt_file, :few_shot_examples_file, :rate_limit

    def initialize
      @enabled = false
      @provider = :openai
      @model = "gpt-4o-mini"
      @max_tokens = 4000
      @temperature = 0.1
      @rate_limit = 20
    end

    def validate!
      errors = []
      errors << "ai provider required" if enabled && !provider
      errors << "ai model required" if enabled && !model
      errors << "ai api_key_file required" if enabled && !api_key_file
      errors
    end
  end

  class DashboardConfig
    attr_accessor :min_refresh_interval, :max_widgets, :default_theme, :grid_columns
  end

  class SharingConfig
    attr_accessor :token_length, :default_expiry, :max_expiry
  end

  class SecretsConfig
    attr_accessor :directory, :key_file
  end

  class MiddlewareStack
    def initialize
      @stack = []
    end

    def use(klass, *args, &block)
      @stack << [klass, args, block]
    end

    def build(app)
      @stack.reverse.inject(app) do |next_app, (klass, args, block)|
        klass.new(next_app, *args, &block)
      end
    end
  end
end