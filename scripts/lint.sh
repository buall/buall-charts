#!/usr/bin/env bash
#
# 对 charts/ 下的所有 Helm Chart 执行 lint。依赖 Helm，不会写入集群、镜像仓库
# 或代码仓库。
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for chart in "${root_dir}"/charts/*; do
  [[ -f "${chart}/Chart.yaml" ]] || continue
  helm lint "${chart}"
done
