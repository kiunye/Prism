# Prism Core

Core query engine and read-only enforcement for Prism BI — a pure Ruby gem with no Rails dependency.

## Installation

Add to your Gemfile:

```ruby
gem "prism-core", "~> 0.1"
```

Then run `bundle install`.

## Configuration

Prism is configured via a `Prism.configure` block, typically in `config/initializers/prism.rb`:

```ruby
Prism.configure do |config|
  # Required: Return the "owner" for scoping resources (User, Team, Account, or nil)
  config.owner_resolver = ->(request) { Current.user&.team }

  # Required: Runs before every Prism request. Raise or return false to deny access.
  config.auth_guard = ->(request) { request.env["warden"].authenticate!(:admin) }

  # Optional: Custom middleware for the query pipeline
  config.middleware.use TenantIsolationMiddleware
  config.middleware.use AuditLogMiddleware

  # Database connections
  config.connection :primary do |c|
    c.slug = "primary"
    c.name = "Primary Database"
    c.adapter = :postgresql
    c.reuse_host_pool = true           # Use host app's ActiveRecord pool
    c.read_only_role = "prism_ro"      # Required: Postgres role with SELECT-only grants
    c.default = true
  end

  config.connection :analytics do |c|
    c.slug = "analytics"
    c.name = "Analytics Replica"
    c.adapter = :postgresql
    c.reuse_host_pool = false          # Independent connection pool
    c.credentials_file = "secrets/analytics_db.yml"
    c.read_only_role = "prism_ro"
    c.pool_size = 3
    c.statement_timeout = 60
  end

  # Table visibility
  config.visibility.mode = :allowlist  # :allowlist, :denylist, or :dynamic
  config.visibility.allowlist = %w[users orders order_items products teams subscriptions]

  # Query limits
  config.query.max_rows = 10_000
  config.query.timeout = 30
  config.query.rate_limit = 60
  config.query.statement_timeout = 30
  config.query.enable_explain = true

  # Cache TTL profiles (seconds)
  config.cache.ttl_profiles = {
    dashboard_widget: 30,
    schema: 3600,
    ai_context: 600,
    query_result: 60,
  }

  # AI querying
  config.ai.enabled = true
  config.ai.provider = :openai
  config.ai.model = "gpt-4o-mini"
  config.ai.api_key_file = "secrets/openai.yml"
  config.ai.max_tokens = 4000
  config.ai.temperature = 0.1
  config.ai.system_prompt_file = "prism/ai_system_prompt.md"
  config.ai.few_shot_examples_file = "prism/ai_examples.yml"
  config.ai.rate_limit = 20

  # Dashboards
  config.dashboard.min_refresh_interval = 30
  config.dashboard.max_widgets = 50
  config.dashboard.default_theme = :dark
  config.dashboard.grid_columns = 12

  # Sharing
  config.sharing.token_length = 32
  config.sharing.default_expiry = 30.days
  config.sharing.max_expiry = 365.days

  # Secrets
  config.secrets.directory = Rails.root.join("secrets")
  config.secrets.key_file = "secrets/master.key"
end
```

## Connection Pools

### Host Pool Reuse
When `reuse_host_pool: true`, Prism wraps the host app's `ActiveRecord::Base.connection_pool` and executes `SET ROLE prism_ro` on each checkout. The host app must have a `prism_ro` role with `SELECT`-only grants.

### Independent Pool
When `reuse_host_pool: false`, Prism creates a `PG::ConnectionPool` with credentials from a YAML file (mode 0400):

```yaml
# secrets/analytics_db.yml
host: analytics-db.example.com
port: 5432
database: analytics
username: prism_user
password: "super-secret"
```

The connection options enforce read-only at the driver level:
```
-c default_transaction_read_only=on
-c statement_timeout=30000
-c application_name=prism_analytics
```

## Read-Only Enforcement (Multi-Layer)

1. **Postgres Role**: `prism_ro` role with `GRANT SELECT ON ALL TABLES IN SCHEMA public TO prism_ro`
2. **Driver Options**: `default_transaction_read_only=on`
3. **Transaction Wrapper**: `BEGIN READ ONLY` + `SET LOCAL statement_timeout`
4. **AST Validation**: `pg_query` parses SQL and rejects non-SELECT statements

## Query Execution

```ruby
engine = Prism::Core::QueryEngine.new(
  connection_manager: manager,
  timeout: 30_000,
  max_rows: 10_000
)

result = engine.execute(
  "SELECT * FROM users WHERE created_at > {{start_date}}",
  variables: {
    definitions: [{ name: "start_date", type: "date", default: "2024-01-01" }],
    values: { start_date: "2024-03-01" }
  },
  connection_slug: "primary"
)

result.rows        # => [{"id" => 1, "email" => "a@b.com", ...}, ...]
result.columns     # => ["id", "email", "created_at", ...]
result.row_count   # => 42
result.duration_ms # => 15.3
result.to_csv($stdout) # streams CSV
```

## Schema Inspection

```ruby
inspector = Prism::Core::SchemaInspector.new(connection_manager, visibility_config)

inspector.tables("primary")                    # => ["orders", "users", "products"]
inspector.columns("primary", "users")          # => [{name: "id", data_type: "integer", primary_key: true, ...}, ...]
inspector.foreign_keys("primary", ["orders", "users"])
  # => [{"from_table" => "orders", "from_column" => "user_id", "to_table" => "users", "to_column" => "id"}]
inspector.sample_rows("primary", "users", limit: 3, max_columns: 5)
```

## AI Schema Context

```ruby
builder = Prism::Core::SchemaContextBuilder.new(connection_manager, visibility_config)
context = builder.build("primary", token_budget: 8000)
# Returns compact string:
# DATABASE SCHEMA
# ========================================
# TABLE USERS
# ------------
#   id: integer NOT NULL 🔑
#   email: character varying NOT NULL
#   created_at: timestamp without time zone NOT NULL
#   -- SAMPLE
#   --   "1" | "a@b.com" | "2024-01-15T10:30:00Z"
#
# TABLE ORDERS
# ------------
#   id: integer NOT NULL 🔑
#   user_id: integer NOT NULL
#   total: numeric(10,2) NOT NULL
#   -- SAMPLE
#   --   "101" | "1" | "99.99"
#
# RELATIONSHIPS
# ============
#   orders.user_id → users.id
```

## Required Postgres Setup

```sql
CREATE ROLE prism_ro NOINHERIT;
GRANT CONNECT ON DATABASE your_app TO prism_ro;
GRANT USAGE ON SCHEMA public TO prism_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO prism_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO prism_ro;
ALTER ROLE prism_ro SET default_transaction_read_only = on;
ALTER ROLE prism_ro SET statement_timeout = '30s';
```

## Secrets File Format

Credential files must have permissions `0400`:

```bash
chmod 0400 secrets/analytics_db.yml
```

```yaml
# secrets/analytics_db.yml
host: analytics-db.example.com
port: 5432
database: analytics
username: prism_user
password: "super-secret"
```

## Testing

```bash
cd prism-core
bundle exec rake test
```

Tests run without Rails loaded (pure Ruby).

## License

MIT