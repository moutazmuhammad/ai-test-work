# Test Plan — Nuclio single-gateway invocation

Verifies: the split Istio route/AuthorizationPolicy (`nuclio-dashboard` / `nuclio-invoke`
in `values/charts/AWS/aib_platform.yaml`) actually lets external clients invoke any Nuclio
function through one fixed host, while the dashboard/admin API stays behind login.

## 0. Prerequisites
- `kubectl` context pointed at the target cluster, `helm` available.
- Know which chart release renders `aib_platform.yaml` (the `aib-platform` umbrella
  chart / mesh-networking + mesh-security subcharts).

## 1. Apply the config changes
```bash
helm upgrade aib-platform charts/aib-platform \
  -f values/charts/common/aib_platform.yaml \
  -f values/charts/AWS/aib_platform.yaml \
  -n aib-system   # adjust release name/namespace to match how it's actually installed
```

## 2. Confirm the Istio objects landed
```bash
kubectl get virtualservice nuclio-dashboard-vs -n aib-auth -o yaml | grep -A3 "pathPrefix\|prefix"
kubectl get authorizationpolicy -n aib-system | grep nuclio
kubectl get authorizationpolicy nuclio-dashboard -n aib-system -o yaml
kubectl get authorizationpolicy nuclio-invoke -n aib-system -o yaml
```
Expect: VS has two routes (`/api/function_invocations` and `/`); `nuclio-dashboard` policy
excludes `/api/function_invocations*`; `nuclio-invoke` is `ALLOW` scoped to that path.

## 3. Deploy the test function
Run the notebook (`deploy_notebook.ipynb`) end to end inside MLRun Jupyter, through the
"Deploy" cell. Confirm in the output:
```
Deploy state: ready
```
Then confirm where it actually landed:
```bash
kubectl get nuclionfunctions -A | grep cvm-agent
```
Namespace must match `FUNCTION_NAMESPACE` in the notebook (`aib-system`).

## 4. Positive test — invoke through the shared gateway (from OUTSIDE the cluster)
```bash
curl -i \
  -H "X-Nuclio-Function-Name: cvm-agent" \
  -H "X-Nuclio-Function-Namespace: aib-system" \
  -H "X-Nuclio-Path: health" \
  https://nuclio.dev.aibplus.vodacom.aws.corp/api/function_invocations
```
Pass criteria: `200`/function's real health response, **no** redirect to Dex/oauth2 login.

Chat stream:
```bash
curl -N -X POST \
  -H "X-Nuclio-Function-Name: cvm-agent" \
  -H "X-Nuclio-Function-Namespace: aib-system" \
  -H "X-Nuclio-Path: chat/stream" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test_user","message":"Hello","session_id":"test_session"}' \
  https://nuclio.dev.aibplus.vodacom.aws.corp/api/function_invocations
```

## 5. Prove it's name-agnostic (the actual point of this design)
Deploy a **second** function under a different name (any throwaway nuclio function is
fine) and repeat step 4 with `X-Nuclio-Function-Name: <new-name>` — same URL, same host,
no config change. Pass criteria: it also invokes successfully, with zero edits to the
Gateway/VirtualService.

## 6. Negative test — admin/dashboard path must still require login
```bash
curl -i https://nuclio.dev.aibplus.vodacom.aws.corp/
```
Pass criteria: redirected to Dex/oauth2-proxy login (302), i.e. the split didn't
accidentally open the whole dashboard.

## 7. Negative test — direct ClusterIP bypass must still be blocked
From a pod that is **not** `mlrun-api` / `mlrun-job-runner` / `default-editor` /
`istio-ingressgateway` (e.g. a scratch debug pod in another namespace):
```bash
kubectl run curl-test --rm -it --image=curlimages/curl -n aibplus-profile -- \
  curl -i -H "X-Nuclio-Function-Name: cvm-agent" -H "X-Nuclio-Function-Namespace: aib-system" \
  http://nuclio-dashboard.aib-system.svc.cluster.local:8070/api/function_invocations
```
Pass criteria: denied (RBAC/`nuclio-dashboard-internal` DENY policy still in effect) —
confirms invocation isn't reachable by an unintended shortcut inside the mesh.

## 8. Troubleshooting if it fails
```bash
kubectl logs -n aib-system -l app=nuclio,nuclio.io/app=dashboard --tail=100
kubectl logs -n istio-system -l istio=ingressgateway --tail=100
istioctl proxy-config route <ingressgateway-pod> -n istio-system -o json | grep -A20 function_invocations
```
Common causes: VS not picked up (check `kubectl get gateway,virtualservice -A`), wrong
namespace header (404/error from Nuclio, not from Istio), AuthorizationPolicy ordering
(CUSTOM/DENY/ALLOW evaluated together — a typo in selector labels silently no-ops a policy).

## 9. Rollback
```bash
git revert <commit>   # or helm rollback aib-platform <previous-revision>
```

## Known open gap (not tested here, by design)
Step 4/5 succeed with **no application-level auth** on the invoke path (see TODOs in
`aib_platform.yaml`) — that's expected today, not a bug. Before real external traffic
relies on this, add JWT (Dex) or API-key auth to the `nuclio-invoke` policy and re-run
step 4 to confirm unauthenticated requests are now rejected.
