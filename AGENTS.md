# AGENTS.md — Prism Build Steering Document

This file governs how any agent, human or AI, builds Prism. It is binding. If a
decision made during implementation conflicts with this file, stop and flag
the conflict rather than resolving it silently.

Companion document: `prism_prd_v2.md` holds the product definition, user
flows, data model, and technical design. This file holds the rules for how
that product gets built.

---

## 0. Agent Roster

Every implementation decision is guided by one or more of these five
disciplines. When a task touches more than one, apply all of them, don't pick
the most convenient one.

| Agent | Owns |
|---|---|
| `/rails-expert` | Architecture, Active Record design, Hotwire patterns, background jobs, caching, testing strategy, Rails-idiomatic structure |
| `/dhh-ruby-style` | Ruby and Rails code style: thin controllers, fat models, REST purity, naming, syntax |
| `/security-engineer` | Threat modeling, secrets handling, dependency and container scanning, defense in depth |
| `/docker-expert` | Dockerfile and Compose design, image size and build time, container hardening |
| `/high-end-visual-design` | Every screen a user sees. No exceptions for "internal tool" or "admin-only" reasoning |

`/karpathy-guidelines` sits above all five and gates every decision made by
any of them. See Section 1.

---

## 1. The Prime Directive: Karpathy Guidelines First

Before any code is written, edited, or generated, run it through these checks
in order. This is not a suggestion, it's a gate.

**1. Think before coding.** State assumptions explicitly. If more than one
interpretation of a task exists, name them, don't silently pick one. If a
simpler approach exists than the one implied by the request, say so before
building the complicated one. If something is unclear, stop and ask rather
than guessing.

**2. Simplicity first.** Write the minimum code that solves the stated
problem. No speculative features, no configurability nobody asked for, no
abstraction built for a single call site, no error handling for scenarios
that can't occur. If a change comes out at 200 lines and could be 50, it gets
rewritten before it ships.

**3. Surgical changes.** Touch only what the task requires. Don't refactor
adjacent code, don't reformat files you're passing through, don't "improve"
things nobody asked about. Match existing style even when you'd have chosen
differently. Remove only the imports, variables, or functions your own change
made unused, leave pre-existing dead code alone and mention it instead of
deleting it.

**4. Goal-driven execution.** Every task gets a verifiable success criterion
before work starts. "Add validation" becomes "write a test for the invalid
case, then make it pass." "Fix the bug" becomes "reproduce it in a test,
then make that test pass." A task without a way to verify it's done isn't
ready to start.

### Rule 2 (project-specific, non-negotiable)

**If a workaround needs a paragraph-long comment to justify why it's okay,
the code is wrong. Fix the code, don't explain the hack.** A comment is
allowed to explain *why* a non-obvious decision was made. A comment is never
allowed to apologize for a piece of code that shouldn't exist in that form.
If you catch yourself writing that comment, that's the signal to stop and
redesign the two or three lines around it instead.

---

## 2. Git Workflow

Gitflow, strictly. No phase names, task names, or ticket-shaped clutter in
branch or commit names, ever. A commit message describes what changed, not
where it sits in a roadmap.

### Branches

- `main` — always deployable. Only release merges and hotfixes land here.
- `develop` — integration branch. All feature work merges here first.
- `feature/<short-slug>` — off `develop`. Example: `feature/read-only-query-role`, not `feature/phase-1-query-engine`.
- `fix/<short-slug>` — off `develop` for non-urgent bug fixes. Example: `fix/schema-cache-invalidation`.
- `release/<version>` — off `develop` when preparing a version, e.g. `release/0.2.0`.
- `hotfix/<short-slug>` — off `main` for urgent production fixes, merged back into both `main` and `develop`.

Slugs are two to four words, kebab-case, describing the change itself:
`feature/dashboard-widget-refresh`, not `feature/build-dashboards`.

### Commits

Conventional Commits, no exceptions. Format is `type(scope): summary`, scope
optional but preferred when it aids scanning history.

Types in use: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`,
`style`, `ci`, `build`, `revert`. Security-relevant fixes use `fix(security):`
rather than a new type.

Good: `feat(query-engine): enforce read-only role at connection time`
Good: `fix(security): reject multi-statement SQL via pg_query validation`
Bad: `feat: phase 1 task 3 - query engine work`
Bad: `wip`

Commit body explains *why* when the diff alone doesn't make it obvious.
Never explains a workaround that should have been a fix instead, per Rule 2.

### Pull Requests

Every `feature/*` and `fix/*` branch merges via PR into `develop`, never
pushed directly. PR description states the verifiable success criterion from
Section 1, and confirms it was actually verified, not just asserted.

---

## 3. Code Style

Ruby and Rails code follows DHH's 37signals style throughout, applied by
`/dhh-ruby-style` and enforced by `/rails-expert`.

- **REST purity.** Only the seven standard actions. New behavior gets a new
  controller, never a custom action bolted onto an existing one.
- **Thin controllers, fat models.** Controller actions stay one to five
  lines. Business logic, query safety enforcement, and broadcasting live on
  models and, where `prism-core` is Rails-free, on plain Ruby objects with a
  single clear responsibility.
- **Current attributes** for request-scoped context (current owner, current
  connection) rather than threading parameters through every call.
- **Bang methods and fail-fast.** `create!`, `update!`, and specific rescue
  blocks rather than swallowing exceptions broadly.
- **Modern Ruby syntax throughout:** `%i[ ]` for symbol arrays with inner
  spacing, modern hash syntax, predicate methods ending in `?`, expression-less
  `case` for multi-branch conditionals.
- **Private methods indented one level under `private`.**
- **Minimal abstraction.** Service objects only when controller logic
  genuinely exceeds what a fat model method should hold, not by default.
  This is where Rule 2 and DHH's own "no service objects for simple cases"
  philosophy agree, so there's no tension to resolve here.
- **Semantic naming.** Associations named for what they mean
  (`owner`, not `user`; `connection`, not `db`), scopes named for what they
  return (`with_visible_tables`, not `scope1`).

`prism-core` is pure Ruby with none of the above Rails-specific pieces
(no controllers, no Current attributes), but the same clarity-over-cleverness
standard applies: small classes, one responsibility each, no premature
interfaces.

---

## 4. Security Decisions

Owned jointly by `/security-engineer` and `/docker-expert`, grounded in the
security model already fixed in the PRD. These are decisions, not options to
reconsider mid-build.

### Application layer

- **The read-only Postgres role is the actual security boundary**, not the
  keyword blocklist. Every query connection Prism uses to run user or
  AI-generated SQL must be bound to a role with `SELECT`-only grants.
- **Statement-shape validation via `pg_query`** runs before every execution,
  rejecting multi-statement input and confirming a single top-level read-only
  statement. This is a real parser check, not a regex.
- **The keyword blocklist is UX**, giving a fast, readable rejection in the
  editor. It never gets treated as the safety boundary in code or in review.
- **Startup safety check.** On boot, Prism attempts a write against the
  configured query connection. If it succeeds, log a loud, unsuppressable
  warning. This check itself is never disabled by configuration.
- **Variables are always parameterized**, never string-interpolated into SQL.
- **System tables and Prism's own storage tables are hardcoded-denied**
  regardless of host visibility configuration.
- **AI schema context is built strictly from the visibility allowlist.** The
  AI layer never receives the full schema, and this is enforced in
  `prism-core`, not left to prompt instructions.
- **Share tokens** are long, unguessable, individually revocable, and scoped
  server-side to exactly one resource, never to a query surface.

### Secrets and credentials

- Stored database credentials are encrypted at the application layer.
- Runtime secrets are delivered as files with restrictive permissions
  (`0400`), mounted read-only, excluded from version control. Never plain
  environment variables for anything credential-shaped.
- No secret, key, or credential is ever logged, including in error messages
  or AI provider request logs.

### Dependency and code scanning

- `brakeman` runs in CI on every PR, zero unaddressed high or critical
  findings before merge.
- `bundler-audit` runs in CI on every PR against the current gem lockfile.
- Both gates block merge to `develop`, not just `main`.

### Container security (owned by `/docker-expert`)

- Multi-stage Dockerfiles, final image contains no build toolchain.
- Non-root user in every container, explicit `USER` directive.
- `.dockerignore` excludes secrets, `.env` files, and local credentials from
  the build context entirely, not just from the final image.
- Base images pinned to a specific digest, not a floating tag, reviewed and
  bumped on a regular cadence rather than left to drift.
- `HEALTHCHECK` defined for every long-running service.
- No database port published to the host network. Storage and target
  databases are reachable only on the internal Compose network.
- Explicit memory and CPU limits on every service so one runaway query or
  job can't take the host down.

### Deployment (plain Compose, not Swarm)

- Caddy as the reverse proxy, automatic HTTPS, minimal configuration surface.
- Scheduled, encrypted, off-host backups of Prism's storage database.
- Environment parity between local Compose and production Compose files,
  differing only in what the PRD's deployment section already specifies.

---

## 5. Design Guide

Owned by `/high-end-visual-design`, adapted for a server-rendered Hotwire
stack rather than a React SPA. The aesthetic bar is identical, the
implementation surface is Tailwind utility classes, Stimulus controllers, and
CSS transitions rather than a JS animation library. "This is an internal
analytics tool" is not a reason to lower the bar, Prism's own dashboards are
the product's shop window.

### Non-negotiables

- **No default AI-generated look.** No Inter/Roboto/Arial as the primary
  typeface, no generic 1px gray borders, no flat `shadow-md` drop shadows, no
  edge-to-edge sticky navbar glued to the viewport top, no instant state
  changes without a transition.
- **Pick a vibe deliberately, once, and hold it.** Given Prism's subject
  matter (data, SQL, dashboards), the natural fit is the Ethereal Glass
  archetype: deep near-black background, restrained glow accents, hairline
  borders, glass panels on cards and the SQL editor chrome. This gets decided
  once at the start of frontend work, documented, and not re-rolled per
  screen.
- **Double-bezel card architecture** for every major container: dashboard
  cards, the query result pane, the schema sidebar. Outer shell with a subtle
  tinted background and hairline ring, inner core with its own background and
  a soft inset highlight, radii calculated so the two nest concentrically.
- **Generous whitespace.** Section padding starts at what would feel
  excessive by default-Bootstrap standards and gets dialed back only if it
  actively hurts data density on the dashboard grid, which is the one place
  in this product where density legitimately competes with breathing room.
- **Motion is physical, never linear.** Custom cubic-bezier transitions, hover
  states that scale and shift rather than only recolor, dashboard widgets
  that fade and lift into place on load rather than popping in.
- **GPU-safe only.** Animate `transform` and `opacity` exclusively, never
  `top`, `left`, `width`, or `height`. `backdrop-blur` only on fixed or sticky
  chrome (nav, modals), never on the scrolling dashboard canvas or the query
  result grid, which is exactly where a naive implementation would be tempted
  to add it.
- **Mobile is a real target**, even for an admin-facing tool. Asymmetric
  layouts collapse to a clean single column below `768px` with no rotated or
  overlapping elements left behind to create touch-target conflicts.

### Where this applies hardest

The SQL editor, the dashboard grid, and the AI chat panel are Prism's three
signature surfaces. These three get the full design treatment first and set
the visual language everything else (settings screens, connection forms,
the schema browser) inherits from, rather than each screen reinventing its
own texture.

---

## 6. Build Plan

Sequencing carried over from the PRD's roadmap overview, expanded into
concrete, verifiable milestones per the Section 1 goal-driven execution rule.
No phase or task names appear in branches or commits, this section is for
planning and review only, not for naming things in git history.

### Milestone: Monorepo Bootstrap

- Root repo structure with `prism-core`, `prism-web`, `docker/`, `docs/`.
- Each subproject boots independently and its own test suite runs green
  before any feature work begins.
- Verify: the test suite passes with zero failures in both `prism-core` and
  `prism-web` on a fresh clone.

### Milestone: Core Query Engine and Read-Only Enforcement

- `prism-core`: configuration object, connection manager, `pg_query`-backed
  statement validator, query engine wired to a read-only role, variable
  interpolator with parameterized binding.
- Verify: a test suite that asserts a write statement is rejected before it
  reaches Postgres, a multi-statement input is rejected by the parser check
  (not just the keyword check), and a legitimate `SELECT` with variables
  executes and returns rows.

### Milestone: Rails Engine Embedding

- `prism-web`: mountable engine, install generator, base controllers, auth
  hook, schema browser, SQL editor with the double-bezel treatment.
- Verify: a bare host Rails app can mount the engine, run the generator, and
  execute a real read-only query end to end through the UI.

### Milestone: Zero-Redis Deployment Proof

- Plain Compose stack, Caddy, Solid Queue, Solid Cache, Solid Cable, no Redis
  container anywhere in the stack.
- Verify: the stack starts from a clean checkout and serves the mounted
  engine over HTTPS locally with no Redis dependency present anywhere in the
  compose configuration.

### Milestone: Dashboards and Sharing

- Persisted dashboards, widgets, chart rendering, GridStack layout, dashboard
  filters bound to URL params, auto-refresh over Solid Cable, public share
  tokens scoped to a single resource.
- Verify: a dashboard with two widgets on different chart types can be
  created, filtered, shared via a public link that an unauthenticated
  request can load, and refreshes on its configured interval without a full
  page reload.

### Milestone: AI Querying

- RubyLLM integration in `prism-core`, schema-context builder scoped to the
  visibility allowlist, AI chat Stimulus controller with streamed responses,
  persisted conversations.
- Verify: an AI-generated query runs through the identical validation and
  execution path as a hand-written query, no shortcut around read-only
  enforcement exists for AI-authored SQL, and a query against a table outside
  the allowlist never appears in the schema context sent to the provider.

### Milestone: Standalone App

- Devise auth, teams and roles, connection registration UI, theme
  persistence, billing integration seam, mounted `prism-web` under `/app`.
- Verify: a fresh deploy of the standalone app supports signup, team
  creation, connecting a real Postgres database through the UI, and using
  the full querying and dashboard flow as a non-admin role with correctly
  scoped permissions.

### Milestone: Deployment and Operational Hardening

- Production Compose file, secret file templates, backup job, resource
  limits, container hardening pass from Section 4.
- Verify: a from-scratch production-shaped deploy on a clean VPS boots
  correctly, an intentionally-attempted write against the query connection
  is rejected and logged, and a restore-from-backup drill actually succeeds.

Each milestone above is a `feature/*` branch (or several, if the surface
area warrants splitting), reviewed and merged into `develop` on its own
verified success criterion, not bundled together to hit a phase finish line.
