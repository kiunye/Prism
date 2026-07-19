# Prism — Product Requirements Document (v2)
> Embedded Business Intelligence for Ruby on Rails
> Standalone open source project

---

## 1. Product Overview

### 1.1 What Prism Is

Prism is an embedded business intelligence system for Ruby on Rails applications. It ships as two gems, `prism-core` and `prism-web`, and later as a standalone self-hosted application. A host app adds the gems, mounts an engine, and gets a SQL query editor, schema browser, persisted dashboards with charting, and an AI querying assistant, all running against the host's own database with no external infrastructure beyond Postgres.

### 1.2 Why It Exists

Rails developers who want internal analytics today choose between three unsatisfying paths: standing up a separate BI tool like Metabase, which means a second service, a second auth system, and a second thing to operate; bolting Redis and a job queue onto a small app just to get a dashboard; or writing one-off admin scripts that never get reused. Prism's premise is that a Rails app should be able to answer its own analytics questions using infrastructure it already has: Postgres.

### 1.3 Competitive Position

Two existing projects sit close to Prism and shape what it needs to do differently.

Blazer is the incumbent embedded SQL and dashboard gem for Rails. It is mature, supports many data sources, and covers basic charting and saved queries, but its dashboard and sharing model is dated and it has no first-party AI querying.

QueryLens is a newer mountable Rails engine that adds natural language to SQL on top of a Blazer-like editor, using a provider-agnostic AI layer that already supports most major LLM vendors plus local models. It covers conversational querying and saved queries well, but does not offer persisted, shareable dashboards with charting and layout, which remains Blazer's strength and neither tool combines.

Prism's differentiation is therefore not "AI querying," since that gap is already being filled elsewhere. Prism differentiates on two things:

- A genuinely good, persisted dashboard and sharing layer, the gap that neither Blazer nor QueryLens currently closes well.
- A zero-Redis operational story, since Prism runs entirely on Postgres via the Rails 8 Solid stack, meaning a host app adds one dependency, not three.

AI querying is still part of Prism, but it is treated as a table-stakes feature to build once and build well, not the feature that has to carry the whole product.

### 1.4 Design Philosophy

- Read-only by default. Production-safe from day one, enforced at the database role level, not only in application code.
- No extra infrastructure. Runs inside an existing Rails app on Postgres alone.
- Zero Redis. Background jobs, caching, and websockets all run on the Rails 8 Solid stack.
- Bring your own key. Prism never proxies or stores query data through a third party; AI provider keys belong to the host app.
- Host-app-first. Prism hooks into whatever auth and ownership model the host app already has, rather than assuming one.

### 1.5 Non-Goals (for the foreseeable roadmap)

- Prism is not a data warehouse and does not do ETL or data transformation.
- Prism does not replace the host app's own admin panel or authentication system.
- Prism does not aim to support every database engine at launch. Postgres is the only supported target and storage database until a real second-adapter need appears.
- Prism does not aim to be a multi-tenant SaaS product at launch. The standalone app is a self-hosted reference implementation, not a hosted service.

---

## 2. User Flow

### 2.1 Installation Flow (Host App Developer)

1. Add `prism-core` and `prism-web` to the Gemfile and install.
2. Run the install generator, which scaffolds a configuration initializer, adds environment variable placeholders, sets up a `secrets/` directory with stub files, and appends that directory to `.gitignore`.
3. Configure ownership scoping (who owns a dashboard or saved query), an authentication guard (who is allowed into Prism at all), which tables are visible, and which database connection to use.
4. Mount the engine at a chosen path in the host app's routes.
5. Run migrations for Prism's own storage tables.
6. Boot the app. On first boot, Prism checks whether the configured query connection can execute a write statement. If it can, a loud warning is logged telling the developer to bind a read-only database role instead of relying on the application-layer guard alone.

Guard at this stage: Prism refuses to treat a writable connection as safe. The warning is not optional and cannot be silenced by configuration alone, only by fixing the underlying role.

### 2.2 Querying Flow (End User)

1. User opens the SQL editor inside the mounted engine.
2. User browses the schema sidebar, limited to the tables allowed by the visibility configuration. System tables and Prism's own storage tables are always hidden, regardless of configuration.
3. User writes a query, optionally using typed `{{variable}}` placeholders for reusable filters.
4. On execute, the query passes through, in order: a statement-shape check confirming it parses as a single read-only statement with no stacked queries, a keyword check that gives a fast, readable rejection message for obviously unsafe input, and then execution inside a read-only transaction against a database role that has no write grants at all.
5. Results render in a Turbo Frame with row count and duration. Row output is capped at a configured maximum; a user who needs more must narrow the query or use CSV export.
6. A query that runs past a configured timeout is terminated and the user sees a clear timeout error, not a hung page.
7. User may save the query, attach it to a dashboard later, or export results as a streamed CSV.

Guards in this flow: read-only database role, statement-shape validation, keyword rejection, per-query timeout, max row cap, and per-owner rate limiting on how many queries can run per minute.

### 2.3 Schema Browsing Flow

1. User selects a registered database connection.
2. Prism lazily loads and caches the table list, then column details on table expansion.
3. Only allowlisted tables appear; a table not on the allowlist is invisible, not merely disabled.

### 2.4 Dashboard Flow (End User)

1. User creates a dashboard and gives it a name.
2. User adds widgets, each backed by a saved query, and chooses a chart type.
3. User arranges widgets on a grid layout and sets an optional auto-refresh interval.
4. User adds dashboard-level filters, which bind to URL parameters so filtered views are bookmarkable and shareable as a link.
5. Widgets refresh independently; a slow widget does not block the rest of the dashboard from rendering.
6. If auto-refresh is enabled, widgets update on their interval over a websocket connection without a full page reload.

Guards: dashboard and widget ownership scoping means a user only edits dashboards they own or have been granted access to; auto-refresh intervals have a configured minimum to prevent a widget from hammering the database every few seconds.

### 2.5 Sharing Flow

1. Owner generates a public share token for a dashboard or saved query, with an optional expiry.
2. Anyone with the link can view the shared resource without authenticating.
3. The public route only ever resolves the single resource tied to the token. It cannot be used to browse other dashboards, other tables, or run arbitrary queries.
4. Owner can revoke the token at any time, immediately invalidating the link.

Guards: public routes bypass the authentication hook entirely but are hard-scoped to one resource id resolved from the token; there is no path from a public share into the authenticated application.

### 2.6 AI Querying Flow (End User)

1. User opens the AI chat panel and asks a question in plain language.
2. Prism builds a schema context string from only the allowlisted tables, never the full schema, and sends it along with the user's question to whichever provider and model the host app has configured.
3. The assistant proposes SQL and a plain-language explanation, streamed into the chat as it generates.
4. User reviews the generated SQL before it runs. Nothing executes automatically; the same read-only role, statement validation, and row caps from the manual querying flow apply identically to AI-generated queries.
5. If the query fails, the user can ask the assistant to fix the error, which sends the failure message back for a corrected attempt.
6. User can save a good AI-generated query the same way as a hand-written one.

Guards: schema-context allowlisting so the AI never sees hidden tables, mandatory human review before execution, and identical execution-time safeguards as manual queries, since AI-authored SQL is not treated as more trustworthy than user-authored SQL.

### 2.7 Administration Flow (Host App Developer)

1. Developer sets table visibility as an allowlist, a denylist, or a proc for per-owner dynamic visibility.
2. Developer sets the authentication guard that runs before every Prism request.
3. Developer optionally adds custom middleware to the query pipeline, for example a tenant-isolation check specific to the host app.
4. Developer configures query limits (max rows, timeout, rate limit) and cache TTL profiles per use case.

---

## 3. Data Model

All Prism-managed tables are isolated in Prism's own storage database, prefixed to avoid any collision with the host app's schema.

### 3.1 Database Connection

Represents a registered target database Prism can query. Fields: name, a unique slug used in routes and API calls, the adapter in use (Postgres only for now, with the field reserved for future adapters), a connection specification stored encrypted at the application layer, a flag for whether it reuses the host app's own connection pool versus an independently registered one, a default flag, and a metadata JSON blob for adapter-specific extras.

### 3.2 Saved Query

A reusable, named SQL query. Fields: name, description, the SQL text itself, a JSON array of typed variable definitions (name, type, default, label), polymorphic owner reference, the database connection it targets, a public flag, and free-form tags for organization. Saved queries are the building block for both dashboard widgets and shared links.

### 3.3 Dashboard

A named collection of widgets. Fields: name, unique slug, description, polymorphic owner reference, a public flag, a light or dark theme preference, a serialized grid layout, an optional auto-refresh interval in seconds, and a JSON array of dashboard-level filter definitions.

### 3.4 Widget

A single chart or value on a dashboard, backed by a saved query. Fields: parent dashboard reference, the saved query it runs, a title, chart type, a JSON chart configuration for axes, colors, and aggregation choices, grid position and size, and a JSON map binding widget-level variables to dashboard-level filters.

### 3.5 AI Conversation

A persisted chat thread tied to an owner and a database connection. Fields: polymorphic owner reference, the connection it was scoped to, a title, a JSON array of messages with role, content, and metadata, and the provider and model used for that conversation. Conversations persist so a user can return to earlier reasoning rather than starting fresh each time.

### 3.6 Share Token

A public access grant for a single resource. Fields: the resource type and id it points to, a unique unguessable token, an optional expiry timestamp. Deleting or expiring a token immediately closes the public link with no separate revocation step needed.

### 3.7 Query Cache

An optional persistent cache entry for expensive queries where the standard cache store's TTL semantics are not enough. Fields: a unique cache key, the cached result payload, row count, execution duration, and an explicit expiry timestamp. Most caching goes through the standard Rails cache store; this table exists for cases needing durable, queryable cache metadata.

### 3.8 Ownership Model

Every ownable resource, meaning saved queries, dashboards, and AI conversations, carries a polymorphic owner reference rather than a hard-coded user or team association. The host app supplies a proc that resolves the current owner from the request, whether that is a user, a team, or nothing at all for a single-tenant setup. Prism itself makes no assumption about the host app's domain model.

---

## 4. Technical Design

### 4.1 Stack

- Ruby 3.3 or newer, Rails 8.
- PostgreSQL as the only supported database, both as a query target and as Prism's own storage database.
- Solid Queue for background jobs, Solid Cache for the Rails cache store, Solid Cable for websocket broadcasting. No Redis or other external service.
- Turbo and Stimulus for the frontend, no SPA framework, minimal build tooling.
- CodeMirror for the SQL editor, ApexCharts for charting, GridStack for dashboard layout, all loaded via CDN where practical to avoid a heavy JS build step.
- RubyLLM as the AI provider layer, giving one integration surface across major hosted providers and local models instead of a hand-built adapter per vendor.
- The `pg_query` gem for parsing and validating SQL statement shape ahead of execution, layered on top of the read-only database role that is the actual security boundary.

### 4.2 Architecture

Prism is structured as a gem-first monorepo with three responsibility layers.

`prism-core` is pure Ruby with no Rails dependency. It owns the configuration object, the query engine and its read-only enforcement, the variable interpolator, the schema inspector, the connection manager, the middleware pipeline, the cache adapter layer, and the AI harness built on RubyLLM. Because it has no Rails dependency, it can be tested in isolation and reused outside a Rails context if that is ever useful.

`prism-web` is a mountable Rails engine depending on `prism-core`. It owns the controllers, models, migrations, views, Stimulus controllers, the internal REST API, and the install generator. This is what a host app actually mounts.

The standalone app, planned for a later phase, is a conventional Rails application that mounts `prism-web` and adds the pieces only a self-hosted product needs: user accounts, teams and roles, a connection-registration UI, and a billing integration seam. It should not duplicate logic that belongs in `prism-web`.

Prism maintains a clear separation between two database concerns. Target databases are the ones being queried for analytics, accessed strictly through a read-only role, and can be the host app's own database or a separate connection Prism registers independently. Prism's own storage database holds dashboards, widgets, saved queries, AI conversations, and the Solid stack's own tables, isolated from the host app's schema by table prefixing.

### 4.3 Internal REST API

All routes are namespaced under the engine's mount point and consumed by Stimulus controllers and Turbo Frames.

| Area | Method and Path | Purpose |
|---|---|---|
| Connections | GET /api/v1/connections | List registered connections |
| Connections | GET /api/v1/connections/:slug/schema | Full schema for a connection |
| Connections | GET /api/v1/connections/:slug/tables/:table | Single table schema and sample rows |
| Queries | POST /api/v1/queries/execute | Run SQL against a connection with variables |
| Queries | POST /api/v1/queries/validate | Statement-shape and safety check without execution |
| Saved Queries | GET, POST /api/v1/saved_queries | List and create, scoped to current owner |
| Saved Queries | GET, PATCH, DELETE /api/v1/saved_queries/:id | Show, update, destroy |
| Saved Queries | GET /api/v1/saved_queries/:id/run | Execute with bound variables |
| Saved Queries | POST /api/v1/saved_queries/:id/share | Generate a share token |
| Dashboards | GET, POST /api/v1/dashboards | List and create |
| Dashboards | GET, PATCH, DELETE /api/v1/dashboards/:slug | Show with widgets, update, destroy |
| Dashboards | PATCH /api/v1/dashboards/:slug/layout | Save grid layout |
| Dashboards | POST /api/v1/dashboards/:slug/share | Generate a public share token |
| Widgets | POST, PATCH, DELETE /api/v1/dashboards/:slug/widgets(/:id) | Add, update, remove a widget |
| Widgets | POST /api/v1/dashboards/:slug/widgets/:id/refresh | Force a single widget refresh |
| AI | GET, POST /api/v1/ai/conversations | List and start conversations |
| AI | GET, DELETE /api/v1/ai/conversations/:id | Show or clear a conversation |
| AI | POST /api/v1/ai/conversations/:id/messages | Send a message, streamed response |
| Public | GET /share/:token and /share/:token/data | Unauthenticated access to a single shared resource |

Responses follow a standard envelope carrying a data payload, pagination metadata where relevant, and a null or populated errors array with a machine-readable code and a human-readable message.

### 4.4 Security Model

| Concern | Mitigation |
|---|---|
| Write queries | A dedicated read-only Postgres role granted select-only privileges is the actual boundary, backed by a read-only transaction wrapper as a second layer |
| Multi-statement or disguised writes | Statement-shape validation via `pg_query`, confirming a single top-level read-only statement before execution |
| Obviously unsafe input | A keyword check that gives a fast, readable rejection in the editor, treated as UX, not as the security boundary |
| SQL injection via variables | Variables are parameterized, never interpolated as raw strings |
| System table exposure | A hardcoded denylist covering system catalogs and Prism's own storage tables, enforced regardless of host configuration |
| Unauthorized access | The host app's authentication guard runs before every engine request |
| AI schema leakage | The AI layer only ever receives the allowlisted schema context, never the full schema |
| Public share tokens | Long, unguessable tokens, optional expiry, instantly revocable |
| Stored database credentials | Encrypted at the application layer |
| Runtime credentials | File-based secrets with restrictive filesystem permissions, excluded from version control |
| Connection pool safety | Every query runs inside a transaction with explicit teardown, never left open |
| Unsafe host-connection mode | A startup check attempts a write against the configured connection; if it succeeds, Prism logs a loud, unsuppressable warning that the connection is not actually read-only |

### 4.5 Deployment

Prism targets plain Docker Compose as its documented deployment path, favoring operational simplicity for a solo or small-team operator over the added complexity of an orchestrator like Swarm, which is only justified if a cluster already exists to run it on.

Key elements of the deployment story:

- Caddy as the reverse proxy, chosen over more configurable alternatives for its automatic HTTPS and minimal configuration surface.
- No database port published to the host network; the storage and target databases are reachable only on the internal Compose network.
- Secrets delivered as read-only mounted files with restrictive permissions, kept out of version control, never placed in plain environment variables.
- Containers run as a non-root user.
- Explicit memory and CPU limits per service so a single runaway query or background job cannot take down the host.
- Scheduled, encrypted, off-host backups of Prism's storage database, run as a background job.
- No Redis or other external service; Solid Queue, Solid Cache, and Solid Cable all run against the same Postgres instance that already backs the application.

### 4.6 Roadmap Overview

This PRD intentionally stops short of a task-level build plan, which is the next deliverable to work through separately. At a high level, the sequencing agreed so far is: core query engine, embedding, and the zero-Redis deployment story first, since that is the credibility layer a skeptical adopter needs to trust immediately; dashboards and sharing second, since that is where Prism actually differentiates from existing tools; AI querying third, built once against RubyLLM rather than five separate integrations, since that ground is already partly covered by existing tools and does not need to be rushed; and the standalone app with authentication, teams, and deployment hardening last, once the embedded product already stands on its own.

---

*Prism — Turn your Rails app into its own data platform.*
