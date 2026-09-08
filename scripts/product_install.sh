#!/usr/bin/env bash
set -euo pipefail

########################
# Kyverno
helm upgrade --install kyverno -n kyverno ./charts/kyverno -f values/charts/common/Kyverno.yaml --wait
helm upgrade --install kyverno-policies -n kyverno ./charts/kyverno-policies -f values/charts/common/kyverno-policies.yaml --wait --timeout 10m

########################
helm upgrade --install rbac charts/rbac -f values/charts/common/rbac.yaml -n kube-system
########################
# Foundation
helm upgrade --install foundation  -n kube-system ./charts/foundation -f values/charts/common/foundation.yaml --wait
########################
# Istio base
helm upgrade --install istio-base -n istio-system ./charts/base -f ./charts/base/values.yaml --skip-crds --wait
########################
# helm status istio-base -n istio-system
# helm get all istio-base -n istio-system
########################
# Istiod
helm upgrade --install istiod -n istio-system ./charts/istiod -f values/charts/common/istiod.yaml --wait --timeout 10m
########################
# Istio Ingress Gateway
helm upgrade --install istio-ingressgateway -n istio-system ./charts/gateway -f values/charts/common/istio_ingressgateway.yaml --wait --timeout 10m
########################
# Istio Egress Gateway
helm upgrade --install istio-egressgateway -n istio-system ./charts/gateway -f values/charts/common/istio_egressgateway.yaml --wait --timeout 10m
########################
# secrets for aib-system
kubectl apply -f scripts/secrets.yaml
########################
# MYSQL (external DB for MLRun — replaces the mysql embedded in mlrun-ce)
helm upgrade --install mlrun-mysql -n aib-data charts/mysql -f values/charts/common/mlrun-mysql.yaml
helm upgrade --install kubeflow-mysql -n aib-data charts/mysql -f values/charts/common/kubeflow-mysql.yaml

##

helm upgrade mlrun-mysql -n aib-data charts/mysql -f values/charts/common/mlrun-mysql.yaml --set auth.password=unused --set auth.rootPassword=unused --set auth.replicationPassword=unused
helm upgrade kubeflow-mysql -n aib-data charts/mysql -f values/charts/common/kubeflow-mysql.yaml --set auth.password=unused --set auth.rootPassword=unused --set auth.replicationPassword=unused

########################
# SEAWEEDFS
helm upgrade --install seaweedfs -n aib-data charts/seaweedfs -f values/charts/common/seaweedfs.yaml
########################
# REDIS
helm upgrade --install redis -n aib-data charts/redis -f values/charts/common/redis.yaml
########################
# MLRUN
helm upgrade --install mlrun -n aib-system charts/mlrun-ce -f values/charts/common/mlrun.yaml
########################
helm dependency build charts/aib-platform

helm upgrade --install aib-platform -n istio-system charts/aib-platform -f values/charts/common/aib_platform.yaml
########################
# oauth2-proxy
helm dependency build charts/oauth2-proxy

helm upgrade --install oauth2-proxy -n aib-auth charts/oauth2-proxy -f values/charts/common/oauth2-proxy.yaml
########################
# dex
helm upgrade --install dex charts/dex -f values/charts/common/dex.yaml -n aib-auth
########################
# additional k8s objects
# ArgoCD sync-waves handle ordering automatically. For manual deploys,
# the two-pass apply ensures the Profile creates the namespace before
# the PodDefault is applied.
helm template extra-objects charts/extra-objects -f values/charts/common/extra-objects.yaml | \
  kubectl apply --server-side --force-conflicts -f - 2>/dev/null || true
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/aibplus-profile --timeout=60s
helm template extra-objects charts/extra-objects -f values/charts/common/extra-objects.yaml | \
  kubectl apply --server-side --force-conflicts -f -
########################
helm upgrade --install gke-gateway-api charts/gke-gateway-api -f values/charts/gcp/gke-gateway-api.yaml -n gateway
########################
helm upgrade --install network-policies ./charts/network-policies -f values/charts/common/network-policies.yaml -n kube-system
#########################
helm upgrade --install  central-secret-operator ./charts/central-secret-operator -n  external-secrets -f values/charts/common/central-secret-operator.yaml 
#########################
helm upgrade --install  rai ./charts/rai -n  aib-system -f values/charts/common/rai.yaml
#########################
helm upgrade --install  rai-proxy ./charts/rai-proxy -n  aib-system -f values/charts/common/rai-proxy.yaml 
#########################
helm upgrade --install  kube-prometheus-stack -n  aib-ops ./charts/kube-prometheus-stack  -f values/charts/common/kube-prometheus-stack.yaml 
