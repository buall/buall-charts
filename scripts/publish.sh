#!/usr/bin/env bash
#
# 打包所有 Chart，并将生成的 .tgz 推送到 HELM_OCI_REGISTRY 指定的 OCI 仓库。
# 依赖 Helm Registry 登录；会写入本地 dist/ 文件，并创建远程仓库版本。
set -euo pipefail
: "${HELM_OCI_REGISTRY:?Set HELM_OCI_REGISTRY, for example oci://registry.example.com/charts}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"${root_dir}/scripts/package.sh"
for package in "${root_dir}"/dist/*.tgz; do
  [[ -f "${package}" ]] || continue
  helm push "${package}" "${HELM_OCI_REGISTRY}"
done
