# Publishing Charts

This repository publishes public Helm charts as a traditional GitHub Pages
repository. GitHub Releases hold the packaged chart artifacts, while the
`gh-pages` branch contains `index.yaml`, the chart packages, and Artifact Hub
repository metadata.

## One-time GitHub setup

1. Push this repository to a public GitHub repository whose default branch is
   `main`.
2. Create an empty `gh-pages` branch and configure GitHub Pages to publish from
   that branch at `/`.
3. In Actions settings, allow workflows to have read and write repository
   permissions. The release workflow requires `contents: write` to create
   releases and update `gh-pages`.
4. Push a chart version not already published. Chart versions are immutable;
   increment `charts/<name>/Chart.yaml` before every chart release.

The workflow at `.github/workflows/release-charts.yml` validates the charts,
creates GitHub Releases, packages every changed chart, and updates the Helm
repository index. With a repository at `https://github.com/<org>/<repo>`, the
published Helm repository URL is:

```text
https://<org>.github.io/<repo>
```

Users can install from it with:

```bash
helm repo add ops-charts https://<org>.github.io/<repo>
helm repo update
helm install db ops-charts/postgresql --version 0.1.1
```

Before the first release, add the public GitHub repository URL to the
`sources` field in each chart's `Chart.yaml`. This repository currently has no
Git remote, so that URL cannot be resolved safely in source yet.

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
