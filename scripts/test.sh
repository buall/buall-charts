#!/usr/bin/env bash
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
    rendered_extensions="$(helm template package-postgresql "${package}" -f "${extensions_values}")"
    rendered_custom_db="$(helm template package-postgresql "${package}" -f "${custom_db_values}")"
    grep -q 'CREATE EXTENSION IF NOT EXISTS "pg_cron";' <<<"${rendered_extensions}"
    grep -q "cron.database_name = 'postgres'" <<<"${rendered_extensions}"
    grep -q 'mountPath: /docker-entrypoint-initdb.d' <<<"${rendered_extensions}"
    grep -q "cron.database_name = 'app'" <<<"${rendered_custom_db}"
  fi
done
