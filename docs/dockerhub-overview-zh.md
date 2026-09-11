# PostgreSQL Stack

基于 [PostgreSQL Docker Hub 官方镜像](https://hub.docker.com/_/postgres) 构建的增强版 PostgreSQL 镜像，内置经过验证的扩展组合。

## 内置扩展

- **TimescaleDB**：时序数据能力，支持 hypertable、连续聚合、保留策略等功能；使用官方源码编译。
- **pg_cron**：数据库内定时任务调度器；使用 PGDG 包安装。
- **pgAudit**：PostgreSQL 审计日志扩展；使用 PGDG 包安装。
- **repmgr**：PostgreSQL 主备复制与故障转移管理工具；使用 PGDG 包安装。

支持 PostgreSQL `14.24`、`15.19`、`16.15`、`17.11` 和 `18.6`。所有 tag 均支持 `linux/amd64` 与 `linux/arm64`。

## 扩展版本

下表为执行 `CREATE EXTENSION` 后，在数据库 `pg_extension` 中报告的版本：

| PostgreSQL | TimescaleDB | pg_cron | pgAudit | repmgr |
| --- | --- | --- | --- | --- |
| 14.24 | 2.19.3 | 1.6 | 1.6.3 | 5.5 |
| 15.19 | 2.28.3 | 1.6 | 1.7.1 | 5.5 |
| 16.15 | 2.30.0 | 1.6 | 16.1 | 5.5 |
| 17.11 | 2.30.0 | 1.6 | 17.1 | 5.5 |
| 18.6 | 2.30.0 | 1.6 | 18.0 | 5.5 |

`pg_cron` 安装的 PGDG Debian 包版本为 `1.6.8-1.pgdg13+1`，但扩展对数据库报告的版本为 `1.6`。

## Docker 使用

启动 PostgreSQL 18：

```bash
docker run -d \
  --name postgres-stack \
  -e POSTGRES_PASSWORD=change-me \
  -e POSTGRES_DB=app \
  -p 5432:5432 \
  -v postgres_data:/var/lib/postgresql/data \
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
CREATE EXTENSION IF NOT EXISTS repmgr;
SQL
```

> `pg_cron` 只能在一个数据库中创建；`cron.database_name` 必须与创建 `pg_cron` 扩展的数据库一致。

## Helm Chart 使用

```yaml
image:
  registry: docker.io
  repository: buall/postgres-stack
  tag: "18.6"

auth:
  database: app
  password: change-me

postgresql:
  extensions:
    - timescaledb
    - pg_cron
    - pgaudit
    - repmgr
  configuration: |-
    pgaudit.log = 'write, ddl'
```

Chart 会在首次初始化时自动创建扩展，并自动配置 TimescaleDB、pg_cron 和 pgAudit 所需的 `shared_preload_libraries`。启用 pg_cron 时，`cron.database_name` 默认跟随 `auth.database`。

## 注意事项

- 生产环境应启用持久化存储，并明确设置 CPU 和内存 requests/limits。
- pgAudit 需要按实际合规要求配置 `pgaudit.log` 审计策略。
- repmgr 已验证主备注册与克隆；高可用部署仍需自行配置复制、repmgrd、故障转移和 witness。
- TimescaleDB 包含完整功能，发布镜像或提供托管服务前请确认许可证符合使用场景。
