# PostgreSQL extension images

These Dockerfiles extend the official `docker.io/library/postgres` image with
TimescaleDB, `pg_cron`, pgAudit, and repmgr. They preserve the official image
contract used by the chart (`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`,
`PGDATA`, and `/docker-entrypoint-initdb.d/`).

Each PostgreSQL major version has its own directory. TimescaleDB is built from
its pinned official source release in a builder stage, without the Apache-only
build option. pg_cron, pgAudit, and repmgr are installed as pinned packages from
the **PGDG apt repository** (`apt.postgresql.org`), which the official
`postgres` images already configure for their Debian release.

| Directory | PostgreSQL | TimescaleDB | pg_cron | pgAudit | repmgr |
| --- | --- | --- | --- | --- | --- |
| `14/` | 14.24 | 2.19.3 | 1.6 | 1.6.3 | 5.5.0 |
| `15/` | 15.19 | 2.28.3 | 1.6 | 1.7.1 | 5.5.0 |
| `16/` | 16.15 | 2.30.0 | 1.6 | 16.1 | 5.5.0 |
| `17/` | 17.11 | 2.30.0 | 1.6 | 17.1 | 5.5.0 |
| `18/` | 18.6 | 2.30.0 | 1.6 | 18.0 | 5.5.0 |

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

After publishing an image, enable the extensions in the chart values. Note that
the chart composes the reference as `registry/repository:tag`, so the registry
and repository must be set separately:

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
    - repmgr
```

The chart then generates the idempotent `CREATE EXTENSION` statements and adds
the required preload libraries for `timescaledb`, `pg_cron`, and `pgaudit`
(`repmgr` is installed as an extension but is not a preload library).
