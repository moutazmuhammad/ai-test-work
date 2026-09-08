# Notes: 

## Updates:
- Updated the MLRun Helm chart by modifying the Nuclio subchart service configuration to support ClusterIP type, instead of being restricted to NodePort only.
    * `aib-plus-dev-work/charts/mlrun-ce/charts/nuclio/templates/service/dashboard.yaml`
- Updated the MLRun Helm chart by modifying DB templates to support an external S3 service (installed from seperate chart)
    * `charts/mlrun-ce/charts/mlrun/templates/db-configmap-init.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-configmap.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-deployment.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-exporter-service.yml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-secret.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/db-service.yaml` 
    * `charts/mlrun-ce/charts/mlrun/templates/mlrun-db-pvc.yaml` 
    * `charts/mlrun-ce/charts/mlrun/values.yaml` 
    * `charts/mlrun-ce/templates/_helpers.tpl` 
- Update the MLRun Helm chart (Nuclio chart) by adding containerSecurityContext
    * `charts/mlrun-ce/charts/nuclio/templates/deployment/controller.yaml`
    * `charts/mlrun-ce/charts/nuclio/templates/deployment/dashboard.yaml`
- Update Istiod helm chart: change hard coded public image to GCP AR
    * `charts/istiod/files/grpc-simple.yaml`
- The chart template hardcodes WEED_MYSQL_USERNAME and WEED_MYSQL_PASSWORD env vars from seaweedfs-db-secret (lines 104-115), but your values file also sets them via extraEnvironmentVars and secretExtraEnvironmentVars with the correct credentials from seaweedfs-db-credentials. During helm upgrade, Kubernetes strategic merge patch merges env entries by name, creating a single entry with both value and valueFrom — which is invalid.
    * `charts/seaweedfs/templates/filer/filer-statefulset.yaml`
