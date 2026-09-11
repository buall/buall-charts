#!/usr/bin/env bash
#
# 渲染、打包、lint 并再次渲染每个 Chart，以校验默认 values 与
# ci/<chart>/values-*.yaml。脚本使用退出时自动删除的本地临时目录，
# 不会连接 Kubernetes 集群。
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="$(mktemp -d)"
trap 'rm -rf "${package_dir}"' EXIT

for chart in "${root_dir}"/charts/*; do
  [[ -f "${chart}/Chart.yaml" ]] || continue
  name="$(basename "${chart}")"
  helm template "test-${name}" "${chart}" >/dev/null
  for values in "${root_dir}/ci/${name}"/values-*.yaml; do
    [[ -f "${values}" ]] || continue
    helm template "test-${name}" "${chart}" -f "${values}" >/dev/null
  done

  helm package "${chart}" --destination "${package_dir}" >/dev/null
  package="$(find "${package_dir}" -maxdepth 1 -type f -name "${name}-*.tgz" -print -quit)"
  [[ -n "${package}" && -f "${package}" ]] || {
    echo "packaged chart not found for ${name}" >&2
    exit 1
  }
  if tar -tzf "${package}" | grep -q '/\.idea/'; then
    echo "IDE metadata leaked into ${package}" >&2
    exit 1
  fi
  helm lint "${package}" >/dev/null
  helm template "package-${name}" "${package}" >/dev/null
  for values in "${root_dir}/ci/${name}"/values-*.yaml; do
    [[ -f "${values}" ]] || continue
    helm template "package-${name}" "${package}" -f "${values}" >/dev/null
  done

  if [[ "${name}" == "postgresql" ]]; then
    extensions_values="${root_dir}/ci/postgresql/values-extensions.yaml"
    custom_db_values="${root_dir}/ci/postgresql/values-extensions-custom-db.yaml"
    nodeport_values="${root_dir}/ci/postgresql/values-nodeport.yaml"
    rendered_extensions="$(helm template package-postgresql "${package}" -f "${extensions_values}")"
    rendered_custom_db="$(helm template package-postgresql "${package}" -f "${custom_db_values}")"
    rendered_nodeport="$(helm template package-postgresql "${package}" -f "${nodeport_values}")"
    grep -q 'CREATE EXTENSION IF NOT EXISTS "pg_cron";' <<<"${rendered_extensions}"
    grep -q "cron.database_name = 'postgres'" <<<"${rendered_extensions}"
    grep -q 'mountPath: /docker-entrypoint-initdb.d' <<<"${rendered_extensions}"
    grep -q "cron.database_name = 'app'" <<<"${rendered_custom_db}"
    grep -q 'type: NodePort' <<<"${rendered_nodeport}"
    grep -q 'nodePort: 30254' <<<"${rendered_nodeport}"
    if helm template package-postgresql "${package}" --set service.nodePort=30254 >/dev/null 2>&1; then
      echo "service.nodePort should require a NodePort or LoadBalancer Service" >&2
      exit 1
    fi
  fi
done
