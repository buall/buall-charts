# PostgreSQL

此 chart 使用 PostgreSQL 官方 [`postgres`](https://hub.docker.com/_/postgres)
镜像部署单实例 PostgreSQL。它不使用 Bitnami 镜像、`bitnami/common`、
`/opt/bitnami` 或 Bitnami 环境变量。

此 chart 面向单实例场景，不提供高可用、多个副本、复制、自动备份或原地
跨大版本升级功能。

## 快速开始

```bash
helm install db ./charts/postgresql
```

默认镜像为 `docker.io/library/postgres:16.4`。Chart 版本与 PostgreSQL 的
`appVersion` 相互独立；可以通过设置 `image.tag` 使用其他 PostgreSQL 版本：

```bash
helm install db ./charts/postgresql --set image.tag=18.6
```

当前已验证可以使用以下 PostgreSQL 版本：

- 14.24
- 15.19
- 16.15
- 17.11
- 18.6

上述版本均已验证 PostgreSQL 启动、数据读写、PVC 持久化、Pod 重建后的数据
保留、Helm 卸载/重新安装后的数据保留，以及 metrics exporter 数据采集。

## 模板结构

模板采用按职责拆分的结构。可复用 helper 分别位于
`_names.tpl`、`_labels.tpl`、`_images.tpl`、`_resources.tpl`、
`_affinities.tpl`、`_secrets.tpl`、`_probes.tpl` 和 `_storage.tpl`；实际
资源模板位于 `configmaps/`、`services/` 和 `monitoring/` 目录下。

这种结构使每个模块保持简单，便于阅读和维护，避免所有逻辑集中在单个大型
模板文件中。

## 认证配置

开发环境可以直接在 values 中配置：

```yaml
auth:
  username: app
  password: change-me
  database: app
```

生产环境建议在 Helm 之外创建 Secret，避免将密码写入 Git：

```bash
kubectl create secret generic app-postgres-auth \
  --from-literal=username=app \
  --from-literal=password='use-a-secret-manager' \
  --from-literal=database=app
```

然后引用该 Secret：

```yaml
auth:
  existingSecret: app-postgres-auth
  secretKeys:
    usernameKey: username
    passwordKey: password
    databaseKey: database
```

设置 `existingSecret` 后，chart 不会创建或修改该 Secret。升级时 chart 也
不会随机轮换密码。

## 持久化与 StorageClass

持久化默认开启。StatefulSet 使用 `volumeClaimTemplates` 创建一个
`ReadWriteOnce` PVC，默认大小为 20Gi。设置 `persistence.storageClass`
可以覆盖 `global.storageClass`；如果两者都为空，则由 Kubernetes 选择默认
StorageClass。

```yaml
persistence:
  storageClass: fast-ssd
  size: 100Gi
```

只有一次性或临时环境才应设置 `persistence.enabled: false`。此时 chart 使用
`emptyDir`，Pod 被删除后数据会丢失。

本 chart 已针对 PostgreSQL 14.24、15.19、16.15、17.11 和 18.6 验证以下
持久化场景：

1. 写入测试数据到 PostgreSQL。
2. 删除 Pod，等待 StatefulSet 重建，并重新读取数据。
3. 卸载 Helm release，确认 PVC 保留。
4. 使用相同 release 重新安装，并再次读取数据。

## 资源配置

`resourcesPreset` 支持 `none`、`nano`、`micro`、`small`、`medium`、
`large`、`xlarge` 和 `2xlarge`。显式设置的 `resources` 始终优先于
Preset。Preset 适合开发环境；生产环境建议明确设置 CPU 和内存的 requests
与 limits。

## 初始化脚本与 PostgreSQL 配置

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

脚本会挂载到 `/docker-entrypoint-initdb.d/`，仅在官方镜像第一次初始化数据
目录时执行。已有 PVC 不会再次执行这些脚本。PostgreSQL 配置会以文件形式
挂载，并通过 PostgreSQL 原生的 `-c` 参数传入。

如果自定义镜像中已经包含扩展包，chart 可以根据扩展名自动生成幂等的
`CREATE EXTENSION` 语句：

```yaml
image:
  repository: myorg/postgres-with-extensions
  tag: "16.15"

postgresql:
  extensions:
    - timescaledb
    - repmgr
    - pgaudit
    - pg_cron
```

chart 会自动将 `timescaledb`、`pgaudit` 和 `pg_cron` 加入
`shared_preload_libraries`。`repmgr` 会作为数据库扩展初始化，但不会自动
预加载，因为它不是 PostgreSQL 的 preload library。
`images/postgres-extensions/` 中的配套镜像从官方源码编译 TimescaleDB，并通过
固定版本 PGDG 包安装 pg_cron、pgAudit 和 repmgr；镜像中的 PostgreSQL 大版本必须
与 `image.tag` 选择的版本一致。
`images/postgres-extensions/` 中的配套镜像通过 PGDG 包含 PostgreSQL 18 的
repmgr，已完成主备 `primary register`、`standby clone`、`standby register`
和 `repmgr cluster show` 验证。本 Chart 仍是单实例 PostgreSQL Chart，不会配置
复制、`repmgrd`、故障转移、fencing 或 witness；生产环境应在目标环境验证这些 HA
流程。

当启用 `pg_cron` 时，chart 会自动生成
`cron.database_name = '<auth.database>'`，保证扩展初始化脚本和 pg_cron
使用同一个数据库。若数据库名称来自 existing Secret，可显式覆盖：

```yaml
postgresql:
  extensions:
    - pg_cron
  cronDatabaseName: app
```

如果 `postgresql.configuration` 中已经写了
`cron.database_name`，则以用户显式配置为准。

对于其他扩展，或者需要额外加入 preload library 时，可以使用：

```yaml
postgresql:
  sharedPreloadLibraries:
    - pg_stat_statements
```

自动生成的 SQL 会针对 `auth.database` 配置的数据库执行，并且只在
PostgreSQL 数据目录第一次初始化时执行。如果
`postgresql.configuration` 已经包含 `shared_preload_libraries`，则以用户
显式配置为准。PostgreSQL 配置发生变化时会自动触发 StatefulSet 滚动更新；
扩展初始化 SQL 发生变化时，不会对已有 PVC 重复执行。

## Metrics 与 ServiceMonitor

启用 metrics 后，chart 会在同一个 Pod 中运行可选的
`quay.io/prometheuscommunity/postgres-exporter` sidecar，并通过独立的
metrics Service 暴露指标：

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    labels:
      release: kube-prometheus-stack
```

exporter 通过 Secret 引用获取数据库凭据，密码不会写入渲染后的 Pod spec。
`ServiceMonitor` 默认关闭，因此未安装 Prometheus Operator 的集群也可以只
启用 exporter 和 metrics Service。

如果设置 `metrics.serviceMonitor.enabled: true`，集群需要预先安装
Prometheus Operator 的 `ServiceMonitor` CRD。

## 调度与扩展配置

chart 支持 `nodeSelector`、`tolerations`、`affinity`、
`topologySpreadConstraints`、Pod/容器安全上下文、`extraEnvVars`、
`extraVolumes` 和 `extraVolumeMounts`。

`volumePermissions` 是一个可选的 BusyBox init container，用于需要一次性
修正目录属主的 StorageClass，默认关闭。

## 升级说明

PostgreSQL 小版本升级应先在 PVC 副本上进行验证。chart 不会执行 PostgreSQL
大版本原地升级；例如不能直接使用 PostgreSQL 18 镜像启动 PostgreSQL 17 的
数据目录。

跨大版本升级应使用 PostgreSQL 官方迁移流程（例如 dump/restore、`pg_upgrade`）
或 PostgreSQL Operator，并在迁移完成后使用新的数据目录部署 chart。

## 完整配置

完整 values API 请参阅 [`values.yaml`](values.yaml) 和
[`values.schema.json`](values.schema.json)。
