# Chart conventions

This repository treats values as a stable user-facing API. Every chart should
use the following names where the component supports the capability.

## Required shared values

- `global.imageRegistry`, `global.imagePullSecrets`, and `global.storageClass`
  provide cross-chart defaults.
- `image` contains `registry`, `repository`, `tag`, `digest`, and
  `pullPolicy`.
- `resourcesPreset` and `resources` use the common presets `none`, `nano`,
  `micro`, `small`, `medium`, `large`, `xlarge`, and `2xlarge`. Explicit
  resources take precedence.
- `commonLabels`, `commonAnnotations`, `podLabels`, and `podAnnotations` are
  available for metadata customization.
- `serviceAccount`, `podSecurityContext`, and `containerSecurityContext`
  follow Kubernetes names and should default to least privilege.
- `nodeSelector`, `tolerations`, `affinity`, and
  `topologySpreadConstraints` are the standard scheduling escape hatches.
- `extraEnvVars`, `extraVolumes`, and `extraVolumeMounts` are the standard
  escape hatches for uncommon integrations.

## Component-dependent values

`persistence` is required for stateful charts such as PostgreSQL and should
honor `persistence.storageClass > global.storageClass > cluster default`.
Stateless charts may omit it. `metrics` and `serviceMonitor` are enabled only
when a component has a supported exporter; ServiceMonitor is always opt-in.

## PostgreSQL-specific baseline

The PostgreSQL chart uses the upstream image and native variables
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, and `PGDATA`. New charts
must not introduce Bitnami runtime paths or environment variables.

