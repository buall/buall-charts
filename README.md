# middleware-charts

Helm charts for commonly used middleware. The first chart is PostgreSQL,
with the default runtime image
[`docker.io/buall/postgres-stack:18.6`](https://hub.docker.com/r/buall/postgres-stack).
It preserves the PostgreSQL official-image runtime contract rather than using
a vendor-specific runtime.

## Charts

- [`charts/postgresql`](charts/postgresql) - single-instance PostgreSQL with
  persistence, optional `postgres_exporter`, and Prometheus Operator support.

## Install

```bash
helm repo add buall-charts https://buall.github.io/buall-charts
helm repo update
helm upgrade --install postgresql buall-charts/postgresql
```

See [docs/development.md](docs/development.md) for local validation and
[docs/conventions.md](docs/conventions.md) for the shared values API.
See [docs/publishing-charts.md](docs/publishing-charts.md) to publish charts on
GitHub Pages and list them on Artifact Hub.
