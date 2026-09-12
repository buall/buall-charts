# PostgreSQL

This chart deploys one PostgreSQL instance with
[`buall/postgres-stack`](https://hub.docker.com/r/buall/postgres-stack), a
PostgreSQL-compatible image built from the upstream `postgres` image. It does
not use Bitnami images, `bitnami/common`, `/opt/bitnami`, or Bitnami
environment variables. It intentionally does not implement HA, replicas,
replication, automatic backups, or in-place major upgrades.

## Quick start

```bash
helm repo add buall-charts https://buall.github.io/buall-charts
helm repo update
helm upgrade --install postgresql buall-charts/postgresql
```

The default image is `docker.io/buall/postgres-stack:18.6`. The chart version
and the PostgreSQL `appVersion` are independent; use another PostgreSQL tag by
setting `image.tag`.

```bash
helm install postgresql ./charts/postgresql --set image.tag=18.6
```

The following PostgreSQL versions have been verified with this chart:

- 14.24
- 15.19
- 16.15
- 17.11
- 18.6

Each version was verified for PostgreSQL startup, database reads and writes,
PVC persistence, data retention after pod recreation, data retention after
Helm uninstall and reinstall, and metrics exporter collection.

## Template layout

The templates follow a Bitnami-style, single-responsibility layout. Reusable
helpers are split by concern (`_names.tpl`, `_labels.tpl`, `_images.tpl`,
`_resources.tpl`, `_affinities.tpl`, `_secrets.tpl`, `_probes.tpl`, and
`_storage.tpl`), while rendered resources live in focused files under
`configmaps/`, `services/`, and `monitoring/`. This keeps each module small
enough to read and change without searching through one monolithic template.

## Authentication

For a quick development install:

```yaml
auth:
  username: app
  password: change-me
  database: app
```

For production, create a Secret outside Helm and use it instead of storing a
password in Git:

```bash
kubectl create secret generic app-postgres-auth \
  --from-literal=username=app \
  --from-literal=password='use-a-secret-manager' \
  --from-literal=database=app
```

```yaml
auth:
  existingSecret: app-postgres-auth
  secretKeys:
    usernameKey: username
    passwordKey: password
    databaseKey: database
```

When `existingSecret` is set, the chart does not create or modify a Secret.
The chart does not randomly rotate passwords during upgrades.

## Persistence and storage classes

Persistence is enabled by default and uses a StatefulSet
`volumeClaimTemplates` with a 20Gi `ReadWriteOnce` claim. Set
`persistence.storageClass` to override `global.storageClass`; when both are
empty, Kubernetes selects its default StorageClass.

```yaml
persistence:
  storageClass: fast-ssd
  size: 100Gi
```

Set `persistence.enabled: false` only for disposable environments; the chart
then uses `emptyDir` and data is lost when the pod is removed.

The following persistence scenarios have been verified for PostgreSQL 14.24,
15.19, 16.15, 17.11, and 18.6:

1. Write test data to PostgreSQL.
2. Delete the pod, wait for the StatefulSet to recreate it, and read the data
   again.
3. Uninstall the Helm release and confirm that the PVC remains.
4. Reinstall the same release and read the data again.

## Service exposure

The PostgreSQL Service is `ClusterIP` by default. To expose it through a fixed
NodePort, configure an integer in the range accepted by the cluster's
NodePort policy (the Kubernetes default is 30000-32767):

```yaml
service:
  type: NodePort
  nodePort: 30254
```

Leave `service.nodePort` unset to have Kubernetes allocate the port. It is
valid only with `service.type: NodePort` or `LoadBalancer`.

## Resources

`resourcesPreset` supports `none`, `nano`, `micro`, `small`, `medium`,
`large`, `xlarge`, and `2xlarge`. Explicit `resources` always wins over the
preset. Presets are useful for development; production deployments should set
CPU and memory requests/limits explicitly.

## Initialization and PostgreSQL configuration

```yaml
initdbScripts:
  01-extension.sql: |
    CREATE EXTENSION IF NOT EXISTS pg_trgm;

postgresql:
  configuration: |-
    max_connections = 300
    shared_buffers = 1GB
  pgHbaConfiguration: |-
    local all all trust
    host all all 0.0.0.0/0 scram-sha-256
```

Scripts are mounted at `/docker-entrypoint-initdb.d/` and are executed by the
official image only when the data directory is initialized for the first time.
They are not replayed on an existing PVC. PostgreSQL configuration is mounted
as files and passed with PostgreSQL's native `-c` options.

### Common `postgresql.conf` settings

Put server settings under `postgresql.configuration`; the official image does
not support Bitnami-style variables such as `POSTGRESQL_MAX_CONNECTIONS`.

| Area | Setting | Notes |
| --- | --- | --- |
| Connections | `max_connections` | Maximum concurrent database connections; requires a restart and increases memory use. Prefer a connection pool for high client concurrency. |
| Connections | `superuser_reserved_connections` | Slots kept for superusers; requires a restart and must be lower than `max_connections`. |
| Connections | `listen_addresses` | Network interfaces on which PostgreSQL listens; requires a restart. Pair external exposure with a restrictive `pg_hba.conf`. |
| Memory | `shared_buffers` | PostgreSQL shared buffer cache size; requires a restart. Size it together with the container memory limit. |
| Memory | `effective_cache_size` | Planner estimate of OS and PostgreSQL cache; does not allocate memory. |
| Memory | `work_mem` | Limit for each sort/hash operation, potentially multiple times in a query and per session; not a global allocation. |
| Memory | `maintenance_work_mem` | Working memory for maintenance operations such as `VACUUM` and index creation. |
| Logical replication | `wal_level` | Set to `logical` to enable logical decoding; requires a restart. |
| Logical replication | `max_replication_slots` | Maximum replication slots; requires a restart. Inactive slots can retain WAL, so monitor them. |
| Logical replication | `max_wal_senders` | Maximum processes serving replication or backups; requires a restart. |
| WAL retention | `max_wal_size` | Checkpoint trigger target, not a hard WAL size limit. |
| WAL retention | `min_wal_size` | Amount of WAL retained for recycling after checkpoints. |
| WAL retention | `wal_keep_size` | Minimum WAL retained for standby servers; it does not protect against inactive replication slots. |
| Logging | `log_min_duration_statement` | Log queries whose execution duration meets the threshold in milliseconds; assess log volume and sensitive SQL data. |
| Logging | `log_connections` | Log successful connection attempts. |
| Logging | `log_disconnections` | Log session termination and duration. |
| Logging | `log_line_prefix` | Add stable request, user, database, or process context to log lines. |

For example:

```yaml
postgresql:
  configuration: |-
    max_connections = 300
    shared_buffers = 1GB
    effective_cache_size = 3GB
    work_mem = 16MB
    wal_level = logical
    max_replication_slots = 20
    max_wal_senders = 20
    log_min_duration_statement = 1000
```

Configuration changes update the StatefulSet checksum and trigger a rolling
Pod restart. This is required for settings whose `pg_settings.context` is
`postmaster`, including `max_connections` and the logical-replication
settings. For a complete, version-matched reference, use the PostgreSQL
[complete official manual](https://www.postgresql.org/docs/current/) and its
[Server Configuration reference](https://www.postgresql.org/docs/current/runtime-config.html).
Replace `current` in either URL with the image major version (for example,
`18`). See especially [connections](https://www.postgresql.org/docs/current/runtime-config-connection.html),
[resource consumption](https://www.postgresql.org/docs/current/runtime-config-resource.html),
[WAL](https://www.postgresql.org/docs/current/runtime-config-wal.html), and
[logging](https://www.postgresql.org/docs/current/runtime-config-logging.html).
Inspect supported settings and their change context in the running database:

```sql
SELECT name, setting, unit, context
FROM pg_settings
WHERE name IN (
  'max_connections', 'shared_buffers', 'effective_cache_size', 'work_mem',
  'wal_level', 'max_replication_slots', 'max_wal_senders',
  'log_min_duration_statement'
)
ORDER BY name;
```

For a custom image that already contains the extension packages, the chart can
generate the idempotent `CREATE EXTENSION` statements automatically:

```yaml
image:
  registry: docker.io
  repository: buall/postgres-stack
  tag: "18.6"

postgresql:
  extensions:
    - timescaledb
    - repmgr
    - pgaudit
    - pg_cron
    - postgis
```

The chart automatically adds `timescaledb`, `pgaudit`, and `pg_cron` to
`shared_preload_libraries`. PostGIS and `repmgr` are initialized as database
extensions but are not automatically preloaded because they are not PostgreSQL
preload libraries.
The companion images build TimescaleDB from its official source and install
pg_cron, pgAudit, PostGIS, and repmgr from pinned PGDG packages. The image must match
the PostgreSQL major version selected by `image.tag`.
The companion image set in `images/postgres-extensions/` includes PGDG's
PostgreSQL 18 repmgr package. It was verified with a primary/standby pair:
`primary register`, `standby clone`, `standby register`, and `repmgr cluster
show` all succeeded. This chart remains a single-instance PostgreSQL chart; it
does not configure replication, `repmgrd`, failover, fencing, or a witness.
Validate those HA workflows in the target environment before production use.

When `pg_cron` is requested, the chart also generates
`cron.database_name = '<auth.database>'` so the extension can be created in the
same database as the generated initialization script. Override the target when
the database name comes from an existing Secret:

```yaml
postgresql:
  extensions:
    - pg_cron
  cronDatabaseName: app
```

An explicit `cron.database_name` line in `postgresql.configuration` takes
precedence over the generated setting.
For other extensions, or to add an extra preload library, use:

```yaml
postgresql:
  sharedPreloadLibraries:
    - pg_stat_statements
```

The generated SQL targets the database configured by `auth.database` and runs
only when the PostgreSQL data directory is initialized for the first time. If
`postgresql.configuration` already contains `shared_preload_libraries`, that
explicit setting takes precedence over the generated list. Changes to the
PostgreSQL configuration automatically trigger a StatefulSet rollout; changes
to extension SQL do not replay against an existing PVC.

## Metrics and ServiceMonitor

The optional `quay.io/prometheuscommunity/postgres-exporter` sidecar listens
on a separate metrics Service:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack
```

The exporter obtains credentials through Secret references; passwords are not
written into the rendered pod spec. `ServiceMonitor` is disabled by default,
so clusters without Prometheus Operator are unaffected.

When `metrics.serviceMonitor.enabled: true` is set, the cluster must already
have the Prometheus Operator `ServiceMonitor` CRD installed.

## Scheduling and escape hatches

The chart supports `nodeSelector`, `tolerations`, `affinity`,
`topologySpreadConstraints`, pod/container security contexts, `extraEnvVars`,
`extraVolumes`, and `extraVolumeMounts`. `volumePermissions` is an optional
BusyBox init container for storage classes that require a one-time ownership
fix; it is disabled by default.

## Upgrades

PostgreSQL minor image upgrades should be tested against a copy of the PVC.
Major upgrades are not performed in place by this chart; for example, a
PostgreSQL 18 image must not be started against a PostgreSQL 17 data directory.

For a major-version upgrade, use PostgreSQL's migration procedures (such as
dump/restore or `pg_upgrade`) or a PostgreSQL Operator, then deploy this chart
with the migrated data directory.

## Selected values

See [`values.yaml`](values.yaml) and [`values.schema.json`](values.schema.json)
for the complete API.
