#!/usr/bin/env bash
#
# 将 charts/ 下的所有 Helm Chart 打包到 dist/。依赖 Helm，只创建或更新本地
# .tgz 文件，不会发布到远程仓库。
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${root_dir}/dist"
for chart in "${root_dir}"/charts/*; do
  [[ -f "${chart}/Chart.yaml" ]] || continue
  helm package "${chart}" --destination "${root_dir}/dist"
done
