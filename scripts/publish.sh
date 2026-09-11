#!/usr/bin/env bash
set -euo pipefail
: "${HELM_OCI_REGISTRY:?Set HELM_OCI_REGISTRY, for example oci://registry.example.com/charts}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${root_dir}/scripts/package.sh"
for package in "${root_dir}"/dist/*.tgz; do
  [[ -f "${package}" ]] || continue
  helm push "${package}" "${HELM_OCI_REGISTRY}"
done

