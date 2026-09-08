# MLRun-CE Chart Changes from Upstream (v0.10.0)

This document tracks all modifications made to the public `mlrun-ce` chart (version `0.10.0`).
Chart version bumped to `0.10.0-fixed`.

---

## 1. MLRun Sub-chart (`charts/mlrun/`)

### 1.1 External Database Support (`db.enabled` / `db.existingDsnSecret`)

**Files changed:**
- `charts/mlrun/values.yaml` — added `db.enabled: true` and `db.existingDsnSecret: false`
- `charts/mlrun/templates/db-deployment.yaml`
- `charts/mlrun/templates/db-service.yaml`
- `charts/mlrun/templates/db-configmap.yaml`
- `charts/mlrun/templates/db-configmap-init.yaml`
- `charts/mlrun/templates/db-exporter-service.yml`
- `charts/mlrun/templates/mlrun-db-pvc.yaml`
- `charts/mlrun/templates/db-secret.yaml`

**What changed:**
- All DB-related templates now include a `.Values.db.enabled` guard so the built-in MySQL deployment, service, configmaps, PVC, and exporter can be **disabled** when using an external database (e.g., AWS RDS).
- The condition changed from `{{- if eq .Values.httpDB.dbType "mysql" }}` to `{{- if and (eq .Values.httpDB.dbType "mysql") .Values.db.enabled }}`.
- `db-secret.yaml` is now wrapped with `{{- if not .Values.db.existingDsnSecret }}` so the secret is skipped when a pre-existing DSN secret is provided externally.

### 1.2 Allow Overriding `MLRUN_HTTPDB__API_URL` via `extraEnvKeyValue`

**Files changed:**
- `charts/mlrun/templates/api-chief-deployment.yaml`
- `charts/mlrun/templates/api-worker-deployment.yaml`
- `charts/mlrun/templates/ms-deployment.yaml`

**What changed:**
- The hard-coded `MLRUN_HTTPDB__API_URL` env var is now wrapped with:
  ```yaml
  {{- if not (hasKey (.Values.api.extraEnvKeyValue | default dict) "MLRUN_HTTPDB__API_URL") }}
  ```
- This allows overriding the API URL through values (e.g., to use an Istio VirtualService hostname or an external load balancer URL) without creating a duplicate env var.

### 1.3 Extra Volumes and Volume Mounts for API Pods

**Files changed:**
- `charts/mlrun/templates/api-chief-deployment.yaml`
- `charts/mlrun/templates/api-worker-deployment.yaml`

**What changed:**
- Added support for `api.extraVolumeMounts` and `api.extraVolumes` in both the chief and worker API deployments.
- This enables mounting additional volumes (e.g., TLS certificates, config files) without forking the template further.

---

## 2. Nuclio Sub-chart (`charts/nuclio/`)

### 2.1 Container-level Security Context

**Files changed:**
- `charts/nuclio/templates/deployment/controller.yaml`
- `charts/nuclio/templates/deployment/dashboard.yaml`

**What changed:**
- Added optional `containerSecurityContext` support for both the controller and dashboard containers:
  ```yaml
  {{- if .Values.controller.containerSecurityContext }}
  securityContext:
    {{- toYaml .Values.controller.containerSecurityContext | nindent 10 }}
  {{- end }}
  ```
- Enables setting `runAsNonRoot`, `readOnlyRootFilesystem`, dropping capabilities, etc. at the container level (the upstream chart only supported pod-level `securityContext`).

### 2.2 Dashboard Service Template Fix

**File changed:**
- `charts/nuclio/templates/service/dashboard.yaml`

**What changed:**
- Fixed the enable condition from `.Values.nuclio.enabled` / `.Values.nuclio.dashboard` to `.Values.dashboard.enabled` / `.Values.dashboard.service` (matching the actual values structure).
- Added explicit `targetPort: 8070` to the service port definition.
- Cleaned up formatting and whitespace.

---

## 3. Parent Chart (`charts/mlrun-ce/`)

### 3.1 Configurable MinIO Host (External S3/MinIO)

**File changed:**
- `templates/_helpers.tpl`

**What changed:**
- Added a new helper `mlrun-ce.minio.service.host` that checks for `.Values.minio.externalHost`.
- If `minio.externalHost` is set, it is used instead of the default `minio.<namespace>.svc.cluster.local`.
- Both `mlrun-ce.minio.service.url` and `mlrun-ce.minio-pipeline.service.url` now use this helper.
- This allows pointing MLRun at an external S3-compatible endpoint (e.g., AWS S3 via a gateway or external MinIO).

### 3.2 Job Runner ServiceAccount

**Files changed:**
- `templates/job-runner-serviceaccount.yaml` *(new file)*
- `values.yaml`

**What changed:**
- Added a new template that creates a dedicated `ServiceAccount` for MLRun-submitted function/job pods (training, serving, batch inference).
- Controlled by `jobRunner.serviceAccount.create` (default `true`), with configurable `name` (default `mlrun-job-runner`) and `annotations` (useful for IRSA on AWS).
- Referenced by `MLRUN_FUNCTION__SPEC__SERVICE_ACCOUNT__DEFAULT` in the mlrun values.

### 3.3 KFP Namespace Patch (Init Container)

**Files changed:**
- Configured via values (`api.extraInitContainers`, `api.extraVolumes`, `api.extraVolumeMounts`)

**What changed:**
- Added an init container (`patch-kfp-namespace`) that patches two MLRun Python files at startup to pass `namespace` through to KFP's `create_experiment` call.
- Fixes MLRun 1.10 bug where `create_pipeline` doesn't forward the namespace to KFP in multi-user mode, causing `403 Forbidden` errors.
- The patched files are mounted from an `emptyDir` volume over the originals.
- The default namespace falls back to the user profile namespace (`aibplus-profile`) when not explicitly provided.

### 3.5 Chart Version Bump

**File changed:**
- `Chart.yaml`

**What changed:**
- Version changed from `0.10.0` to `0.10.0-fixed` to distinguish from the upstream release.

---

## Summary Table

| # | Area | Change | Purpose |
|---|------|--------|---------|
| 1 | mlrun/db | `db.enabled` + `existingDsnSecret` guards | Use external DB (e.g., RDS) |
| 2 | mlrun/api | Conditional `MLRUN_HTTPDB__API_URL` | Override API URL via values |
| 3 | mlrun/api | `extraVolumes` / `extraVolumeMounts` | Mount additional volumes |
| 4 | nuclio | `containerSecurityContext` | Container-level security hardening |
| 5 | nuclio | Dashboard service fix | Correct values path + targetPort |
| 6 | mlrun-ce | Configurable MinIO host | External S3/MinIO support |
| 7 | mlrun-ce | Job Runner ServiceAccount | Dedicated SA for MLRun jobs (IRSA) |
| 8 | mlrun/api | KFP namespace patch (init container) | Fix KFP multi-user 403 + namespace default |
| 9 | mlrun-ce | Version bump to `0.10.0-fixed` | Distinguish from upstream |
