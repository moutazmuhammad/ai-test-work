#!/usr/bin/env bash
set -euo pipefail

# Namespaces
export ENV="dev"
export BASE_DOMAIN="dev.plus.aib.vodafone.com"
export OIDC_ISSUER="https://alert.${BASE_DOMAIN}/realms/aibplus_realm"
export OIDC_ISSUER_LOGOUT="https://alert.${BASE_DOMAIN}/realms/aibplus_realm/protocol/openid-connect/logout"
export OIDC_GROUPS_CUSTOM_SCOPE_NAME="groups"
export PROFILE_OWNER="mostafa@vodafone.com"
for file in $(ls values/product/$ENV/*.yaml);
do
  filename=$(basename $file)
  echo Rendering file: $filename
  mkdir -p values/product/$ENV/rendered/
  envsubst < $file > values/product/$ENV/rendered/$filename
done

########################
# Foundation
helm upgrade --install foundation ./charts/foundation \
  -f values/product/$ENV/rendered/foundation-values.yaml \
  --wait
########################
# Istio base
helm upgrade --install istio-base ./charts/base \
  -n istio-system \
  -f ./charts/base/values.yaml \
  --skip-crds \
  --wait
########################
# helm status istio-base -n istio-system
# helm get all istio-base -n istio-system
########################
# Istiod
helm upgrade --install istiod ./charts/istiod \
  -n istio-system \
  -f values/product/$ENV/rendered/istiod-values.yaml \
  --wait --timeout 10m
########################
# Istio Ingress Gateway
helm upgrade --install istio-ingressgateway ./charts/gateway \
  -n istio-system \
  -f values/product/$ENV/rendered/istio-ingressgateway-values.yaml \
  --wait --timeout 10m
########################
# Istio Egress Gateway
helm upgrade --install istio-egressgateway ./charts/gateway \
  -n istio-system \
  -f values/product/$ENV/rendered/istio-egressgateway-values.yaml \
  --wait --timeout 10m
########################
helm dependency build charts/aib-platform

helm upgrade --install aib-platform charts/aib-platform \
  -f values/product/$ENV/rendered/aib-platform-values.yaml \
  -n istio-system
########################
# MLRUN
helm upgrade --install mlrun charts/mlrun-ce -n aib-system -f  values/product/$ENV/rendered/mlrun.yaml
########################
# # MLFLOW
# helm upgrade  --install mlflow charts/mlflow -n aib-system -f  values/product/$ENV/rendered/mlflow.yaml
# ########################
# # MINIO
# export MINIO_ROOT_USER=admin
# export MINIO_ROOT_PASSWORD=admin123

# helm upgrade --install minio charts/minio \
#   --namespace aib-data \
#   --set rootUser=$MINIO_ROOT_USER \
#   --set rootPassword=$MINIO_ROOT_PASSWORD \
#   -f values/product/$ENV/rendered/minio.yaml
########################

# Dex IdP broker
helm upgrade --install dex charts/dex \
 -f values/product/$ENV/rendered/dex.yaml \
 -n aib-auth
########################

# OAuth2 proxy
helm upgrade --install oauth2-proxy charts/oauth2-proxy \
  -f values/product/$ENV/rendered/oauth2-proxy.yaml \
  -n aib-auth
########################

helm template extra-objects charts/extra-objects \
  -f values/product/$ENV/rendered/extra-objects.yaml | \
  kubectl apply --server-side --force-conflicts -f -
  
########################
# Cert Manager
helm upgrade --install cert-manager charts/cert-manager \
  -n cert-manager

########################
# GKE Gateway API
helm upgrade --install gke-gateway-api charts/gke-gateway-api \
  -f values/product/$ENV/rendered/gke-gateway-api.yaml \
  -n gateway