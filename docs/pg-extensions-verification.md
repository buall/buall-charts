# PostgreSQL 扩展镜像（14-18）构建与验证报告

- 日期：2026-09-10
- 验证环境：隔离测试环境
- 验证对象：当前 Dockerfile 构建的镜像，以及由当前源码打包得到的
  `charts/postgresql` Chart。

## 扩展与安装方式

镜像采用混合安装方式：仅 TimescaleDB 使用固定官方源码版本编译；pg_cron、pgAudit
和 repmgr 使用固定版本的 PGDG Debian 包。这样既保留 TimescaleDB 的完整功能，也由
PGDG 负责另外三个扩展与对应 PostgreSQL 大版本的 ABI 和依赖关系。

TimescaleDB 在独立 builder 阶段使用同小版本的
`postgresql-server-dev-<major>` 编译。最终镜像只保留运行时文件，不包含编译器、
CMake 或开发头文件。

| PostgreSQL | TimescaleDB（官方源码） | pg_cron（PGDG） | pgAudit（PGDG） | repmgr（PGDG） |
| --- | --- | --- | --- | --- |
| 14.24 | 2.19.3 | 1.6.8-1.pgdg13+1 | 1.6.3-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 15.19 | 2.28.3 | 1.6.8-1.pgdg13+1 | 1.7.1-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 16.15 | 2.30.0 | 1.6.8-1.pgdg13+1 | 16.1-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 17.11 | 2.30.0 | 1.6.8-1.pgdg13+1 | 17.1-2.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |
| 18.6 | 2.30.0 | 1.6.8-1.pgdg13+1 | 18.0-3.pgdg13+1 | 5.5.0+debpgdg-3.pgdg13+1 |

五个 Dockerfile 均已在远端实际构建成功。构建过程校验了 PostgreSQL 大版本、四个
扩展 control 文件和 TimescaleDB 完整运行时文件；最终镜像不含 CMake。

## Chart 集成验证

使用当前源码打包生成的 Chart 安装五个镜像，验证完成后临时测试资源已清理。

每个 PostgreSQL 版本均完成以下检查：

1. Chart 初始化脚本创建 `timescaledb`、`pg_cron`、`pgaudit` 和 `repmgr`。
2. 自动生成 `shared_preload_libraries=timescaledb,pg_cron,pgaudit` 与
   `cron.database_name=postgres`。
3. TimescaleDB 创建 hypertable、连续聚合与连续聚合策略，并创建保留策略。
4. pg_cron 创建每 10 秒执行一次的任务，并确认任务实际写入数据。
5. pgAudit 启用写审计后，执行 DDL 和 INSERT，并在 PostgreSQL 日志中确认 `WRITE`
   审计记录。
6. repmgr 扩展创建成功。
7. 写入 PVC marker 后删除 Pod，StatefulSet 重建后 marker 仍存在。
8. 卸载 Helm release 后 PVC 仍保留；使用相同 release 重装后 marker 和四个扩展
   仍存在。

| PostgreSQL | 结果 |
| --- | --- |
| 14.24 | PASS |
| 15.19 | PASS |
| 16.15 | PASS |
| 17.11 | PASS |
| 18.6 | PASS |

另对 PostgreSQL 18 验证了 `auth.database=app`：四个扩展均在 `app` 数据库创建，
`cron.database_name=app`，Pod 首次初始化后无容器重启。

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
