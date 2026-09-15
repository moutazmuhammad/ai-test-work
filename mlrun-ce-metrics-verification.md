# mlrun-ce — Verifying What Actually Exposes Metrics

Before wiring up ServiceMonitors/PodMonitors for mlrun-ce (so kube-prometheus-stack in
aib-ops can scrape it), we need to confirm which components actually serve a
Prometheus `/metrics` endpoint. Unlike istio (istiod, gateways), neither the `mlrun`
nor `nuclio` subcharts in `charts/mlrun-ce` ship a native `serviceMonitor` values
key — so this can't be confirmed by reading the chart's values.yaml alone.

There's also an **uncommitted** file already in the tree,
`charts/mlrun-ce/charts/nuclio/templates/service/controller.yaml`, which adds a
Service exposing port 8090 on the assumption that the nuclio controller serves
metrics there. Source inspection of nuclio's GitHub repo casts doubt on this:
the `prometheusPull` metric sink (docs:
https://docs.nuclio.io/en/stable/tasks/configuring-a-platform.html, source:
https://pkg.go.dev/github.com/nuclio/nuclio/pkg/processor/metricsink/prometheus/pull)
lives under `pkg/processor/...` — the **function processor** binary that runs
inside each deployed serverless function — not the controller or dashboard.
Neither `cmd/controller/app/app.go` nor `cmd/dashboard/app/app.go` wire up a
metric sink. So that Service may be pointing at a port nothing listens on.

Run the checks below against a real cluster to find out, before any
ServiceMonitor/PodMonitor is added for mlrun-ce.

Namespace: `aib-system` (per `scripts/product_install.sh`).

---

## 1. nuclio-controller (port 8090)

Nothing in the current values enables the metrics sink, so first turn it on
temporarily (do **not** commit this — it's just for the test):

```bash
helm upgrade mlrun -n aib-system charts/mlrun-ce \
  -f values/charts/common/mlrun.yaml \
  --set nuclio.platform.metrics.sinks.myPrometheusPull.kind=prometheusPull \
  --set nuclio.platform.metrics.system[0]=myPrometheusPull
```

Then check whether the controller actually listens on 8090:

```bash
kubectl get pods -n aib-system -l nuclio.io/app=controller
POD=$(kubectl get pods -n aib-system -l nuclio.io/app=controller -o jsonpath='{.items[0].metadata.name}')

# logs — look for anything mentioning metrics / listening on 8090
kubectl logs -n aib-system "$POD" | grep -i -E "metric|listen|8090"

# no Service exists yet, so port-forward straight to the pod
kubectl port-forward -n aib-system "$POD" 8090:8090
```

In a second terminal:

```bash
curl -s localhost:8090/metrics | head -20
```

- Prometheus text output (`# HELP` / `# TYPE` lines) → it works ✅
- `curl: (7) Failed to connect` → nothing is listening; the pending
  `controller.yaml` Service would be monitoring a dead port ❌

## 2. nuclio-dashboard (port 8070 — Service already exists)

Easiest to check since the Service is already there:

```bash
kubectl port-forward -n aib-system svc/nuclio-dashboard 8070:8070
```

```bash
curl -s localhost:8070/metrics | head -20
```

Same interpretation as above.

## 3. mlrun-api / mlrun-api-chief (port 8080 — Service already exists)

```bash
kubectl port-forward -n aib-system svc/mlrun-api-chief 8080:8080
```

```bash
curl -s localhost:8080/metrics | head -20
curl -s localhost:8080/openapi.json | grep -io '"/metrics"'   # confirms whether the route is even registered
```

If both come back empty/404, the pinned `mlrun-api:1.10.0` image likely
predates MLRun's newer OpenTelemetry/Prometheus REST-metrics feature
(`mlrun_rest_request_duration_milliseconds` etc.), which showed up in
recent/unreleased MLRun versions.

## 4. mlrun-ui

Frontend only (nginx serving a static app) — not a `/metrics` target under
normal circumstances. Skip it.

---

## Checklist to fill in after testing

| Component | Service exists? | To confirm |
|---|---|---|
| nuclio-controller | ❌ (pending, uncommitted `controller.yaml`) | Does 8090 listen once `platform.metrics.system` is enabled |
| nuclio-dashboard | ✅ (8070) | Does `/metrics` return real data |
| mlrun-api-chief | ✅ (8080) | Does `/metrics` exist on 1.10.0 |
| mlrun-api (worker) | ✅ (8080) | Same check |
| mlrun-ui | ✅ (80) | Not a target — skip |

Once this is filled in, only wire up ServiceMonitor/PodMonitor (and, where
needed, a Service) for whatever is confirmed to actually serve `/metrics`.
Drop or fix the pending `controller.yaml` Service if 8090 turns out to be a
dead port.
