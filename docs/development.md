# Development

Requirements: Helm 3.17+ and a POSIX shell.

```bash
./scripts/lint.sh
./scripts/test.sh
./scripts/package.sh
```

`test.sh` renders every `ci/*/values-*.yaml` file and the chart defaults. It
also packages the chart into a temporary `.tgz`, lints and renders that package,
checks that IDE metadata is excluded, and asserts the extension/initdb wiring.
It does not contact a Kubernetes cluster. Add a new chart under `charts/` and a
matching `ci/<chart>/` directory to include it in these checks.

For a cluster-level test using images already loaded on the nodes, run:

```bash
CHART_PACKAGE=dist/postgresql-0.1.0.tgz \
IMAGE_REGISTRY=registry.example.com \
IMAGE_REPOSITORY=postgres-extensions \
IMAGE_TAG_SUFFIX=<image-tag-suffix> \
./scripts/test-integration.sh
```

`test-integration.sh` installs only the packaged chart, validates PostgreSQL
14.24 through 18.6, checks all four extensions, preload libraries and a
TimescaleDB write/read operation, and covers a non-default `auth.database`.
It removes its temporary namespace on exit. The broader extension and
persistence verification procedure is recorded in
`docs/pg-extensions-verification.md`.
