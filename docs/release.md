# Release

`Chart.yaml:version` is the chart release version. `Chart.yaml:appVersion` is
the default application image version; they are intentionally independent.

Before releasing, run lint and template checks, review rendered manifests for
credentials and image provenance, then package with `scripts/package.sh`.

