#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for chart in "${root_dir}"/charts/*; do
  [[ -f "${chart}/Chart.yaml" ]] || continue
  helm lint "${chart}"
done

