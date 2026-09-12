# PostgreSQL 扩展镜像（14-18）构建与验证报告

- 日期：2026-09-12
- 镜像构建环境：远程 Docker Buildx（`linux/amd64`、`linux/arm64`）
- 镜像验证对象：当前 Dockerfile 构建并推送的 `buall/postgres-stack` 镜像。
- Chart 验证对象：由当前源码打包的 `postgresql-0.1.2.tgz`。

## 扩展与安装方式

镜像采用混合安装方式：仅 TimescaleDB 使用固定官方源码版本编译；pg_cron、pgAudit、
PostGIS 和 repmgr 使用固定版本的 PGDG Debian 包。这样既保留 TimescaleDB 的完整功能，
也由 PGDG 负责另外四个扩展与对应 PostgreSQL 大版本的 ABI 和依赖关系。PostGIS 同时
安装 `postgresql-<major>-postgis-3-scripts`，提供空间数据导入工具。

TimescaleDB 在独立 builder 阶段使用同小版本的
`postgresql-server-dev-<major>` 编译。最终镜像只保留运行时文件，不包含编译器、
CMake 或开发头文件。

| PostgreSQL | TimescaleDB（官方源码） | pg_cron（PGDG） | pgAudit（PGDG） | PostGIS（PGDG） | repmgr（PGDG） |
| --- | --- | --- | --- | --- | --- |
| 14.24 | 2.19.3 | 1.6.8-1.pgdg13+1 | 1.6.3-2.pgdg13+1 | 3.6.4+dfsg-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 15.19 | 2.28.3 | 1.6.8-1.pgdg13+1 | 1.7.1-2.pgdg13+1 | 3.6.4+dfsg-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 16.15 | 2.30.0 | 1.6.8-1.pgdg13+1 | 16.1-2.pgdg13+1 | 3.6.4+dfsg-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 17.11 | 2.30.0 | 1.6.8-1.pgdg13+1 | 17.1-2.pgdg13+1 | 3.6.4+dfsg-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 18.6 | 2.30.0 | 1.6.8-1.pgdg13+1 | 18.0-3.pgdg13+1 | 3.6.4+dfsg-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |

五个 Dockerfile 均已在远端实际构建成功，并推送到 Docker Hub。每个 tag 均发布
`linux/amd64` 和 `linux/arm64` manifest。构建过程校验了 PostgreSQL 大版本、五个
扩展 control 文件和 TimescaleDB 完整运行时文件；最终镜像不含 CMake。

## Chart 集成验证

使用远程 Kubernetes 集群执行当前的 `scripts/test-integration.sh`，Chart 包和镜像来源为：

```bash
CHART_PACKAGE=dist/postgresql-0.1.2.tgz \
IMAGE_REGISTRY=docker.io \
IMAGE_REPOSITORY=buall/postgres-stack \
HELM_TIMEOUT=8m \
./scripts/test-integration.sh
```

脚本以临时 `postgresql-integration` namespace 部署每个版本；测试以 exit code `0`
结束，随后确认该 namespace 与全部测试 Helm release 均已删除。

每个 PostgreSQL 版本均完成以下检查：

1. Chart 初始化脚本创建 `timescaledb`、`pg_cron`、`pgaudit`、`postgis` 和 `repmgr`。
2. 自动生成 `shared_preload_libraries=timescaledb,pg_cron,pgaudit` 与
   `cron.database_name=postgres`。
3. TimescaleDB 创建 hypertable 并完成两行写入和读取。
4. PostGIS 执行 `ST_SetSRID(ST_MakePoint(121.47, 31.23), 4326)`，返回
   `POINT(121.47 31.23)`。
5. 非默认 `auth.database=app` 场景在 `app` 中创建五个扩展，生成
   `cron.database_name=app`，且首次初始化后容器重启次数为零。

| PostgreSQL | 结果 |
| --- | --- |
| 14.24 | PASS |
| 15.19 | PASS |
| 16.15 | PASS |
| 17.11 | PASS |
| 18.6 | PASS |

本次测试为无持久化存储的镜像与 Chart 兼容性测试。PVC 保留、连续聚合、pg_cron 任务
执行、pgAudit 审计日志和 PG18 主备流程应继续在目标生产环境按各自需求验证。

## PG18 repmgr 主备验证

除单实例 Chart 验证外，PG18 的 repmgr 还在隔离的 Docker 主备环境中完成了：

1. `repmgr primary register` 注册主库。
2. `repmgr standby clone` 通过 `pg_basebackup` 克隆备库。
3. `repmgr standby register` 注册已启动的备库。
4. `repmgr cluster show` 显示主库与备库均为 running 且 active。

Chart 本身仍是单实例部署，不负责配置 replication、`repmgrd`、自动故障转移、
switchover、rejoin、fencing 或 witness。

## 发布前注意事项

- TimescaleDB 的完整源码构建包含受 Timescale License 约束的功能。发布镜像或提供
  托管服务前，必须确认许可证与部署、分发方式相符。
- TimescaleDB 源码 tag 与 PGDG 包版本已经固定，但源码归档尚未校验 SHA256；生产
  发布前应补充校验和。
- pgAudit 默认不记录业务审计日志。验证中通过 `ALTER SYSTEM` 临时启用了
  `pgaudit.log`；生产环境应在 `postgresql.configuration` 中明确配置审计策略。
- PG18 repmgr 已通过主备克隆、注册和拓扑识别验证；上游支持信息仍有不一致，生产
  环境应验证实际使用的完整 HA 流程。
