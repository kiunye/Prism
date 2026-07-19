# Prism

Embedded Business Intelligence for Ruby on Rails — a SQL query editor, schema browser, persisted dashboards with charting, and an AI querying assistant, all running against your own Postgres with zero external infrastructure.

See [`AGENTS.md`](AGENTS.md) for build rules and [`prism_prd.md`](prism_prd.md) for the full product specification.

## Development

```powershell
cd prism-core; bundle install; bundle exec rake test
cd ..\prism-web; bundle install; bundle exec rake test
```