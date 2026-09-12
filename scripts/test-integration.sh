#!/usr/bin/env bash

# 将已打包的 PostgreSQL Chart 安装到 Kubernetes 集群，验证各受支持 PostgreSQL
# 版本的扩展初始化、持久化和 metrics 相关配置。脚本会创建临时 namespace 与
# release，并在退出时删除。
#
# 集群节点必须已包含或能够拉取所需镜像。
#
# 必填输入：
#   CHART_PACKAGE       已打包 postgresql-*.tgz 文件的路径。
#
# 可选输入：
#   TEST_NAMESPACE       临时 namespace（默认：postgresql-integration）
#   IMAGE_REGISTRY       镜像仓库域名（默认：registry.example.com）
#   IMAGE_REPOSITORY     镜像仓库路径（默认：postgres-extensions）
#   IMAGE_TAG_SUFFIX     追加到 14.24/15.19/... 的 tag 后缀（默认：空）
#   HELM_TIMEOUT         Helm 等待超时（默认：5m）
#
# 示例：
#   CHART_PACKAGE=dist/postgresql-0.1.2.tgz \
#   IMAGE_TAG_SUFFIX=.locked \
#   ./scripts/test-integration.sh

set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chart_package="${CHART_PACKAGE:-${root_dir}/dist/postgresql-0.1.2.tgz}"
test_namespace="${TEST_NAMESPACE:-postgresql-integration}"
image_registry="${IMAGE_REGISTRY:-registry.example.com}"
image_repository="${IMAGE_REPOSITORY:-postgres-extensions}"
image_tag_suffix="${IMAGE_TAG_SUFFIX:-}"
helm_timeout="${HELM_TIMEOUT:-5m}"

[[ -f "${chart_package}" ]] || {
  echo "chart package not found: ${chart_package}" >&2
  exit 1
}

releases=()
namespace_created=false
cleanup() {
  set +e
  for release in "${releases[@]}"; do
    helm uninstall "${release}" --namespace "${test_namespace}" >/dev/null 2>&1
  done
  if [[ "${namespace_created}" == true ]]; then
    kubectl delete namespace "${test_namespace}" --wait=true --timeout=60s >/dev/null 2>&1
    kubectl delete namespace "${test_namespace}" --wait=false >/dev/null 2>&1
  fi
}
trap cleanup EXIT

if kubectl get namespace "${test_namespace}" >/dev/null 2>&1; then
  echo "test namespace already exists: ${test_namespace}; choose another TEST_NAMESPACE" >&2
  exit 1
fi
kubectl create namespace "${test_namespace}" >/dev/null
namespace_created=true

run_psql() {
  local pod="$1"
  local database="$2"
  local sql="$3"
  kubectl --namespace "${test_namespace}" exec "${pod}" -c postgresql -- \
    psql -U postgres -d "${database}" -v ON_ERROR_STOP=1 -Atqc "${sql}"
}

for version in 14.24 15.19 16.15 17.11 18.6; do
  major="${version%%.*}"
  release="integration-pg${major}"
  pod="${release}-postgresql-0"
  image_tag="${version}${image_tag_suffix}"
  releases+=("${release}")

  helm upgrade --install "${release}" "${chart_package}" \
    --namespace "${test_namespace}" \
    --set-string "image.registry=${image_registry}" \
    --set-string "image.repository=${image_repository}" \
    --set-string "image.tag=${image_tag}" \
    --set image.pullPolicy=IfNotPresent \
    --set 'postgresql.extensions={timescaledb,pg_cron,pgaudit,postgis,repmgr}' \
    --set persistence.enabled=false \
    --set metrics.enabled=false \
    --set resourcesPreset=none \
    --set-string "auth.password=integration-${major}" \
    --wait --timeout "${helm_timeout}" >/dev/null

  kubectl --namespace "${test_namespace}" wait --for=condition=ready \
    "pod/${pod}" --timeout=180s >/dev/null

  extension_count="$(run_psql "${pod}" postgres "SELECT count(*) FROM pg_extension WHERE extname IN ('timescaledb','pg_cron','pgaudit','postgis','repmgr')")"
  preload="$(run_psql "${pod}" postgres 'SHOW shared_preload_libraries')"
  cron_database="$(run_psql "${pod}" postgres 'SHOW cron.database_name')"
  timescale_rows="$(run_psql "${pod}" postgres "DROP TABLE IF EXISTS integration_metrics; CREATE TABLE integration_metrics(ts timestamptz NOT NULL, v integer); SELECT create_hypertable('integration_metrics','ts'); INSERT INTO integration_metrics VALUES (now(),1),(now()+interval '1 minute',2); SELECT count(*) FROM integration_metrics" | tail -n 1)"
  postgis_point="$(run_psql "${pod}" postgres "SELECT ST_AsText(ST_SetSRID(ST_MakePoint(121.47, 31.23), 4326))")"

  [[ "${extension_count}" == "5" ]] || { echo "${version}: expected 5 extensions, got ${extension_count}" >&2; exit 1; }
  [[ "${cron_database}" == "postgres" ]] || { echo "${version}: unexpected cron.database_name=${cron_database}" >&2; exit 1; }
  [[ "${timescale_rows}" == "2" ]] || { echo "${version}: TimescaleDB test returned ${timescale_rows}" >&2; exit 1; }
  [[ "${postgis_point}" == "POINT(121.47 31.23)" ]] || { echo "${version}: PostGIS test returned ${postgis_point}" >&2; exit 1; }
  grep -q 'timescaledb' <<<"${preload}"
  grep -q 'pg_cron' <<<"${preload}"
  grep -q 'pgaudit' <<<"${preload}"

  echo "${version}: extensions=${extension_count} preload=${preload} cron_database=${cron_database} timescale_rows=${timescale_rows} postgis_point=${postgis_point}"
  helm uninstall "${release}" --namespace "${test_namespace}" >/dev/null
done

# A non-default database exercises pg_cron's database-name requirement. The
# chart must generate cron.database_name from auth.database before initdb runs.
release="integration-custom-db"
pod="${release}-postgresql-0"
releases+=("${release}")
helm upgrade --install "${release}" "${chart_package}" \
  --namespace "${test_namespace}" \
  --set-string "image.registry=${image_registry}" \
  --set-string "image.repository=${image_repository}" \
  --set-string "image.tag=16.15${image_tag_suffix}" \
  --set image.pullPolicy=IfNotPresent \
  --set 'postgresql.extensions={timescaledb,pg_cron,pgaudit,postgis,repmgr}' \
  --set auth.database=app \
  --set persistence.enabled=false \
  --set metrics.enabled=false \
  --set resourcesPreset=none \
  --set-string auth.password=integration-app \
  --wait --timeout "${helm_timeout}" >/dev/null
kubectl --namespace "${test_namespace}" wait --for=condition=ready \
  "pod/${pod}" --timeout=180s >/dev/null

custom_extension_count="$(run_psql "${pod}" app "SELECT count(*) FROM pg_extension WHERE extname IN ('timescaledb','pg_cron','pgaudit','postgis','repmgr')")"
custom_cron_database="$(run_psql "${pod}" app 'SHOW cron.database_name')"
custom_restarts="$(kubectl --namespace "${test_namespace}" get pod "${pod}" -o jsonpath='{.status.containerStatuses[0].restartCount}')"
[[ "${custom_extension_count}" == "5" ]] || { echo "custom database: expected 5 extensions, got ${custom_extension_count}" >&2; exit 1; }
[[ "${custom_cron_database}" == "app" ]] || { echo "custom database: unexpected cron.database_name=${custom_cron_database}" >&2; exit 1; }
[[ "${custom_restarts}" == "0" ]] || { echo "custom database: pod restarted ${custom_restarts} times" >&2; exit 1; }
echo "custom database: extensions=${custom_extension_count} cron_database=${custom_cron_database} restarts=${custom_restarts}"
