#!/usr/bin/env bash
set -euo pipefail
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${root_dir}/dist"
for chart in "${root_dir}"/charts/*; do
  [[ -f "${chart}/Chart.yaml" ]] || continue
  helm package "${chart}" --destination "${root_dir}/dist"
done

