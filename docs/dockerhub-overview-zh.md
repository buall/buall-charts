# PostgreSQL Stack

基于 [PostgreSQL Docker Hub 官方镜像](https://hub.docker.com/_/postgres) 构建的增强版 PostgreSQL 镜像，内置经过验证的扩展组合。

## 内置扩展

- **TimescaleDB**：时序数据能力，支持 hypertable、连续聚合、保留策略等功能；使用官方源码编译。
- **pg_cron**：数据库内定时任务调度器；使用 PGDG 包安装。
- **pgAudit**：PostgreSQL 审计日志扩展；使用 PGDG 包安装。
- **PostGIS**：空间数据类型、索引和函数；使用固定版本的 PGDG 包安装，并包含 `shp2pgsql`、`raster2pgsql` 等导入工具。
- **repmgr**：PostgreSQL 主备复制与故障转移管理工具；使用 PGDG 包安装。

支持 PostgreSQL `14.24`、`15.19`、`16.15`、`17.11` 和 `18.6`。所有 tag 均支持 `linux/amd64` 与 `linux/arm64`。

## 扩展版本

下表为执行 `CREATE EXTENSION` 后，在数据库 `pg_extension` 中报告的版本：

| PostgreSQL | TimescaleDB | pg_cron | pgAudit | PostGIS | repmgr |
| --- | --- | --- | --- | --- |
| 14.24 | 2.19.3 | 1.6 | 1.6.3 | 3.6.4 | 5.5 |
| 15.19 | 2.28.3 | 1.6 | 1.7.1 | 3.6.4 | 5.5 |
| 16.15 | 2.30.0 | 1.6 | 16.1 | 3.6.4 | 5.5 |
| 17.11 | 2.30.0 | 1.6 | 17.1 | 3.6.4 | 5.5 |
| 18.6 | 2.30.0 | 1.6 | 18.0 | 3.6.4 | 5.5 |

`pg_cron` 安装的 PGDG Debian 包版本为 `1.6.8-1.pgdg13+1`，但扩展对数据库报告的版本为 `1.6`。

## Docker 使用

启动 PostgreSQL 18：

```bash
docker run -d \
  --name postgres-stack \
  -e POSTGRES_PASSWORD=change-me \
  -e POSTGRES_DB=app \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql \
  buall/postgres-stack:18.6 \
  -c shared_preload_libraries=timescaledb,pg_cron,pgaudit \
  -c cron.database_name=app \
  -c pgaudit.log='write, ddl'
```

首次启动后创建扩展：

```bash
docker exec -i postgres-stack \
  psql -U postgres -d app <<'SQL'
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pgaudit;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS repmgr;
SQL
```

> `pg_cron` 只能在一个数据库中创建；`cron.database_name` 必须与创建 `pg_cron` 扩展的数据库一致。
> PostGIS 不需要加入 `shared_preload_libraries`。

## 服务端参数配置

可在镜像名之后使用 PostgreSQL 原生 `-c` 参数配置服务端。`POSTGRES_*` 环境变量仅
用于首次初始化空数据目录，不能替代 `postgresql.conf`；`POSTGRESQL_MAX_CONNECTIONS`
是 Bitnami 变量，对此镜像无效。

```bash
docker run -d \
  --name postgres-configured \
  -e POSTGRES_PASSWORD=change-me \
  -e POSTGRES_DB=app \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql \
  buall/postgres-stack:18.6 \
  -c max_connections=300 \
  -c shared_buffers=1GB \
  -c wal_level=logical \
  -c max_replication_slots=20 \
  -c max_wal_senders=20
```

大量参数建议挂载 `postgresql.conf`，并追加
`-c config_file=/etc/postgresql/postgresql.conf`。`max_connections`、
`shared_buffers`、逻辑复制参数和 `shared_preload_libraries` 都需要重启才会生效。
完整参数请参阅 PostgreSQL [完整官方手册](https://www.postgresql.org/docs/current/)
和 [服务端配置参数索引](https://www.postgresql.org/docs/current/runtime-config.html)；
将 URL 中的 `current` 替换为镜像大版本号，例如 `18`。

PostgreSQL 18 应将数据卷挂载到 `/var/lib/postgresql`；PostgreSQL 14 至 17 则应
挂载到 `/var/lib/postgresql/data`。

## Helm Chart 使用

Chart 默认使用 `docker.io/buall/postgres-stack:18.6`，因此使用此镜像时不需要
配置 `image`。先添加公开 Chart 仓库，并在目标 namespace 创建凭据 Secret：

```bash
helm repo add buall-charts https://buall.github.io/buall-charts
helm repo update

kubectl create namespace postgresql
kubectl -n postgresql create secret generic postgresql-auth \
  --from-literal=username=postgres \
  --from-literal=password='change-me' \
  --from-literal=database=app
```

创建 `values.yaml`，启用所需扩展及审计配置：

```yaml
auth:
  existingSecret: postgresql-auth

postgresql:
  extensions:
    - timescaledb
    - pg_cron
    - pgaudit
    - postgis
    - repmgr
  # Helm cannot read an existing Secret during rendering, so set this explicitly.
  cronDatabaseName: app
  configuration: |-
    pgaudit.log = 'write, ddl'
```

部署或升级时使用同一个 Helm release：

```bash
helm upgrade --install postgresql buall-charts/postgresql \
  --namespace postgresql \
  --values values.yaml
```

Chart 会在空数据目录的首次初始化时自动创建扩展，并自动配置 TimescaleDB、pg_cron
和 pgAudit 所需的 `shared_preload_libraries`。PostGIS 和 repmgr 不需要预加载。使用 existing Secret 时，Helm 无法在
渲染时读取其中的数据库名；因此本例显式将 `cronDatabaseName` 设为 `app`。已有 PVC
不会重新执行扩展初始化脚本，因此应在首次部署前确定扩展列表。

后续升级先更新仓库索引，再执行同一条 `helm upgrade` 命令：

```bash
helm repo update
helm upgrade postgresql buall-charts/postgresql \
  --namespace postgresql \
  --values values.yaml
```

## 注意事项

- 生产环境应启用持久化存储，并明确设置 CPU 和内存 requests/limits。
- pgAudit 需要按实际合规要求配置 `pgaudit.log` 审计策略。
- repmgr 已验证主备注册与克隆；高可用部署仍需自行配置复制、repmgrd、故障转移和 witness。
- TimescaleDB 包含完整功能，发布镜像或提供托管服务前请确认许可证符合使用场景。
