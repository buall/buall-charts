# PostgreSQL 扩展镜像

这些 Dockerfile 基于 PostgreSQL 官方 `docker.io/library/postgres` 镜像，安装
TimescaleDB、`pg_cron`、pgAudit 和 repmgr。它们保留 chart 所依赖的官方镜像契约，
包括 `POSTGRES_USER`、`POSTGRES_PASSWORD`、`POSTGRES_DB`、`PGDATA` 和
`/docker-entrypoint-initdb.d/`。

每个 PostgreSQL 大版本独立成目录。TimescaleDB 在 builder 阶段从固定的官方源码
版本编译，且未启用 Apache-only 构建选项；pg_cron、pgAudit 和 repmgr 通过固定
版本的 **PGDG apt 仓库**（`apt.postgresql.org`）安装。官方 `postgres` 镜像已按其
Debian 版本预置 PGDG 仓库。

| 目录 | PostgreSQL | TimescaleDB | pg_cron | pgAudit | repmgr |
| --- | --- | --- | --- | --- | --- |
| `14/` | 14.24 | 2.19.3 | 1.6 | 1.6.3 | 5.5.0 |
| `15/` | 15.19 | 2.28.3 | 1.6 | 1.7.1 | 5.5.0 |
| `16/` | 16.15 | 2.30.0 | 1.6 | 16.1 | 5.5.0 |
| `17/` | 17.11 | 2.30.0 | 1.6 | 17.1 | 5.5.0 |
| `18/` | 18.6 | 2.30.0 | 1.6 | 18.0 | 5.5.0 |

表中版本为 `CREATE EXTENSION` 后 `pg_extension` 中报告的扩展版本。Dockerfile
固定 TimescaleDB 源码 tag 与 PGDG 包完整版本号；TimescaleDB 使用同大版本的
`postgresql-server-dev-<major>` 编译，并在构建时校验 PostgreSQL 大版本。

说明：

- TimescaleDB 从官方完整源码构建，连续聚合和保留策略等高级能力可用；发布镜像
  或提供托管服务前，必须确认其许可证符合部署和分发模式。
- PostgreSQL 18 镜像通过 PGDG 的 Debian 适配包 `postgresql-18-repmgr 5.5.0+debpgdg-3`
  包含 repmgr。除创建扩展外，本项目还实测了 PostgreSQL 18 主备的
  `primary register`、通过 `pg_basebackup` 的 `standby clone`、`standby register`
  以及 `repmgr cluster show`。上游 5.5.x 的支持信息存在不一致：兼容矩阵和
  5.5.0 发布说明止于 PostgreSQL 17，而 current 文档首页包含 PostgreSQL 18。
  因此此处将该 PGDG 包定义为“已完成运行时验证”，生产环境仍应验证完整 HA 流程。
- **不要**在这些 Dockerfile 中重复添加 `pgdg.sources`：基础镜像已配置该仓库，
  重复添加会触发 apt 的 `Signed-By` 冲突。

可从目标目录构建，例如：

```bash
docker build --platform linux/amd64 \
  -t registry.example.com/postgres-extensions:<tag> \
  images/postgres-extensions/16
```

镜像发布后，在 chart values 中启用扩展。注意 chart 按
`registry/repository:tag` 拼装镜像引用，因此 registry 与 repository 必须分开设置：

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

随后 chart 会自动生成幂等的 `CREATE EXTENSION` 语句，并为 `timescaledb`、
`pg_cron` 和 `pgaudit` 加入所需的 preload library（`repmgr` 只建扩展，不作为
preload library）。
