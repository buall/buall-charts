# PostgreSQL extension images

These Dockerfiles extend the official `docker.io/library/postgres` image with
TimescaleDB, `pg_cron`, pgAudit, PostGIS, and repmgr. They preserve the official image
contract used by the chart (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`,
`PGDATA`, and `/docker-entrypoint-initdb.d/`).

Each PostgreSQL major version has its own directory. TimescaleDB is built from
its pinned official source release in a builder stage, without the Apache-only
build option. pg_cron, pgAudit, PostGIS, and repmgr are installed as pinned packages from
the **PGDG apt repository** (`apt.postgresql.org`), which the official
`postgres` images already configure for their Debian release.

| Directory | PostgreSQL | TimescaleDB | pg_cron | pgAudit | PostGIS | repmgr |
| --- | --- | --- | --- | --- | --- |
| `14/` | 14.24 | 2.19.3 | 1.6 | 1.6.3 | 3.6.4 | 5.5.0 |
| `15/` | 15.19 | 2.28.3 | 1.6 | 1.7.1 | 3.6.4 | 5.5.0 |
| `16/` | 16.15 | 2.30.0 | 1.6 | 16.1 | 3.6.4 | 5.5.0 |
| `17/` | 17.11 | 2.30.0 | 1.6 | 17.1 | 3.6.4 | 5.5.0 |
| `18/` | 18.6 | 2.30.0 | 1.6 | 18.0 | 3.6.4 | 5.5.0 |

The table shows extension versions reported by `pg_extension` after
`CREATE EXTENSION`. The Dockerfiles pin the TimescaleDB source tag and exact
PGDG package versions. They compile TimescaleDB against a matching
`postgresql-server-dev-<major>` package and assert the PostgreSQL major version
during the build.

Notes:

- TimescaleDB is compiled from the official complete source distribution, so
  advanced features such as continuous aggregates and retention policies are
  available. Its license must be reviewed before distributing an image or
  providing a managed service.
- The PostgreSQL 18 image includes repmgr via PGDG's Debian-patched
  `postgresql-18-repmgr 5.5.0+debpgdg-3`. In addition to extension creation,
  this package was verified with `primary register`, `standby clone` (using
  `pg_basebackup`), `standby register`, and `repmgr cluster show` against a
  PostgreSQL 18 primary/standby pair. The upstream 5.5.x support information is
  inconsistent: its compatibility matrix and 5.5.0 release note end at
  PostgreSQL 17, while the current documentation homepage includes PostgreSQL
  18. Treat the PGDG package as runtime-verified here, and validate your full
  HA workflow before production use.
- Do **not** re-add `pgdg.sources` in these Dockerfiles. The base images already
  configure that repository, and duplicating it causes an apt `Signed-By`
  conflict.

Build an image from the desired directory, for example:

```bash
docker build --platform linux/amd64 \
  -t registry.example.com/postgres-extensions:<tag> \
  images/postgres-extensions/16
```

## Docker runtime configuration

These images retain the official PostgreSQL entrypoint. `POSTGRES_USER`,
`POSTGRES_PASSWORD`, `POSTGRES_DB`, and `POSTGRES_INITDB_ARGS` are bootstrap
variables only: they take effect only while initializing an empty data
directory. They do not configure PostgreSQL server parameters, and changing
them does not modify an existing database.

For a small set of server settings, append native PostgreSQL `-c` arguments to
`docker run`. The image entrypoint passes them to the `postgres` server:

```bash
docker run -d \
  --name postgres-stack \
  -e POSTGRES_PASSWORD=change-me \
  -e POSTGRES_DB=app \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql \
  registry.example.com/postgres-extensions:18.6 \
  -c max_connections=300 \
  -c shared_buffers=1GB \
  -c wal_level=logical \
  -c max_replication_slots=20 \
  -c max_wal_senders=20 \
  -c shared_preload_libraries=timescaledb,pg_cron,pgaudit \
  -c cron.database_name=app
```

The example uses PostgreSQL 18, whose official image persists data beneath
`/var/lib/postgresql`. For PostgreSQL 14 through 17, mount the named volume at
`/var/lib/postgresql/data` instead. Do not use `POSTGRESQL_MAX_CONNECTIONS`:
it is a Bitnami variable and is ignored by these images.

For a managed or longer configuration, mount a file and set it as the server
configuration file:

```conf
# postgresql.conf
max_connections = 300
shared_buffers = 1GB
effective_cache_size = 3GB
work_mem = 16MB
wal_level = logical
max_replication_slots = 20
max_wal_senders = 20
shared_preload_libraries = 'timescaledb,pg_cron,pgaudit'
cron.database_name = 'app'
log_min_duration_statement = 1000
```

```bash
docker run -d \
  --name postgres-stack \
  -e POSTGRES_PASSWORD=change-me \
  -e POSTGRES_DB=app \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql \
  -v "$PWD/postgresql.conf:/etc/postgresql/postgresql.conf:ro" \
  registry.example.com/postgres-extensions:18.6 \
  -c config_file=/etc/postgresql/postgresql.conf
```

`max_connections`, `shared_buffers`, `wal_level`, `max_replication_slots`,
`max_wal_senders`, and `shared_preload_libraries` require a server restart.
Inspect a setting and its change context with
`SHOW max_connections;` or `SELECT name, setting, context FROM pg_settings`.
For the complete, version-matched parameter list, see the PostgreSQL
[official manual](https://www.postgresql.org/docs/current/) and [Server
Configuration reference](https://www.postgresql.org/docs/current/runtime-config.html);
replace `current` with the image major version, such as `18`.

After publishing an image, deploy it through the public chart repository. The
chart composes the reference as `registry/repository:tag`, so the registry and
repository must be set separately for a custom image:

```bash
helm repo add buall-charts https://buall.github.io/buall-charts
helm repo update
```

Set the published custom image and desired extensions in `values.yaml`:

```yaml
image:
  registry: registry.example.com
  repository: postgres-extensions
  tag: "16.15"

postgresql:
  extensions:
    - timescaledb
    - pg_cron
    - pgaudit
    - postgis
    - repmgr
```

The chart then generates the idempotent `CREATE EXTENSION` statements and adds
the required preload libraries for `timescaledb`, `pg_cron`, and `pgaudit`.
PostGIS and repmgr are installed as extensions but are not preload libraries.

```bash
helm upgrade --install postgresql buall-charts/postgresql \
  --namespace postgresql \
  --create-namespace \
  --values values.yaml
```

Extension initialization runs only when the data directory is empty. Changing
the extension list does not create extensions on an existing PVC.
