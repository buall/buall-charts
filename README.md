# middleware-charts

Helm charts for commonly used middleware. The first chart is PostgreSQL,
implemented around the upstream `docker.io/library/postgres` image rather
than a vendor-specific runtime.

## Charts

- [`charts/postgresql`](charts/postgresql) - single-instance PostgreSQL with
  persistence, optional `postgres_exporter`, and Prometheus Operator support.

See [docs/development.md](docs/development.md) for local validation and
[docs/conventions.md](docs/conventions.md) for the shared values API.
See [docs/publishing-charts.md](docs/publishing-charts.md) to publish charts on
GitHub Pages and list them on Artifact Hub.
