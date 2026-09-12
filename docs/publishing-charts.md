# Publishing Charts

This repository publishes public Helm charts through GitHub Pages at
`https://buall.github.io/buall-charts`. GitHub Releases hold the packaged
chart artifacts, while the `gh-pages` branch contains `index.yaml`, the chart
packages, and Artifact Hub repository metadata.

## Use the chart repository

```bash
helm repo add buall-charts https://buall.github.io/buall-charts
helm repo update
helm upgrade --install postgresql buall-charts/postgresql
```

## Release policy

Push a chart version not already published. Chart versions are immutable, so
increment `charts/<name>/Chart.yaml` before every release.

The workflow at `.github/workflows/release-charts.yml` validates the charts,
creates GitHub Releases, packages every changed chart, and updates the Helm
repository index on each push to `main` or manual dispatch. The workflow needs
`contents: write` to create releases and update `gh-pages`.

## Artifact Hub

After the first GitHub Pages release, add the URL above as a public Helm
repository in the [Artifact Hub control panel](https://artifacthub.io/control-panel/repositories).
Artifact Hub reads `index.yaml` and chart package metadata to render the
package page, values, version history, documentation, and install commands.

The workflow publishes `artifacthub-repo.yml` beside `index.yaml`. To claim
the repository and enable the Verified Publisher badge:

1. Copy the repository ID displayed by Artifact Hub into `repositoryID`.
2. Add the Artifact Hub account email under `owners`.
3. Release a new chart version so `index.yaml` changes and Artifact Hub
   processes the updated metadata.

For example:

```yaml
repositoryID: <artifact-hub-repository-id>
owners:
  - name: Platform Team
    email: charts@example.com
```

Artifact Hub is a public catalog. Use Harbor or another private OCI registry
for charts that must not be publicly accessible.
