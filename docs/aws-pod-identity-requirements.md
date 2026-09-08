# AWS EKS Pod Identity — Requirements

This document lists the prerequisites for running the AIB+ platform on AWS EKS
with **EKS Pod Identity** for IAM authentication (no IRSA annotations needed).

---

## 1. EKS Pod Identity Agent Add-on

The EKS Pod Identity Agent must be installed on the cluster. It runs as a DaemonSet
and injects AWS credentials into pods that have a matching association.

```bash
aws eks create-addon \
  --cluster-name <CLUSTER_NAME> \
  --addon-name eks-pod-identity-agent \
  --region <REGION>
```

Verify it is running:

```bash
kubectl get ds eks-pod-identity-agent -n kube-system
```

---

## 2. IAM Roles

Create the following IAM roles with the appropriate trust policies and permission
policies. Each role's trust policy must allow the EKS Pod Identity service principal.

### Trust Policy (same for all roles)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "pods.eks.amazonaws.com"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ]
    }
  ]
}
```

### 2.1 Secrets Manager Role (for External Secrets Operator)

**Role name example**: `aibplus-<market>-secrets-role`

Permission policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ],
      "Resource": "arn:aws:secretsmanager:<REGION>:<ACCOUNT_ID>:secret:aibplus/*"
    }
  ]
}
```

### 2.2 S3 + ECR Role (for MLRun API, job runners, and notebooks)

**Role name example**: `aibplus-<market>-mlrun-runtime-role`

Permission policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::aibplus-<market>-mlrun",
        "arn:aws:s3:::aibplus-<market>-mlrun/*"
      ]
    },
    {
      "Sid": "ECRReadAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2.3 ECR Push Role (for ECR Token Generator CronJob)

**Role name example**: `aibplus-<market>-ecr-push-role`

Permission policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:PutImage"
      ],
      "Resource": "*"
    }
  ]
}
```

---

## 3. Pod Identity Associations

Each service account that needs AWS access must have a Pod Identity association
linking it to the appropriate IAM role.

### 3.1 External Secrets Operator

Allows ESO to read secrets from AWS Secrets Manager.

| Namespace          | Service Account      | IAM Role                          |
|--------------------|----------------------|-----------------------------------|
| `external-secrets` | `external-secrets`   | `aibplus-<market>-secrets-role`   |

```bash
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --region <REGION> \
  --namespace external-secrets \
  --service-account external-secrets \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/aibplus-<market>-secrets-role
```

### 3.2 MLRun API

Allows the MLRun API server (chief + workers) to read/write artifacts in S3.

| Namespace    | Service Account | IAM Role                              |
|--------------|-----------------|---------------------------------------|
| `aib-system` | `mlrun-api`     | `aibplus-<market>-mlrun-runtime-role` |

```bash
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --region <REGION> \
  --namespace aib-system \
  --service-account mlrun-api \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/aibplus-<market>-mlrun-runtime-role
```

### 3.3 MLRun Job Runner

Allows MLRun-submitted function pods (training, serving, batch inference) to
access S3.

| Namespace    | Service Account    | IAM Role                              |
|--------------|--------------------|---------------------------------------|
| `aib-system` | `mlrun-job-runner` | `aibplus-<market>-mlrun-runtime-role` |

```bash
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --region <REGION> \
  --namespace aib-system \
  --service-account mlrun-job-runner \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/aibplus-<market>-mlrun-runtime-role
```

### 3.4 Kubeflow Notebooks (default-editor)

Allows notebook pods in the profile namespace to access S3 for reading/writing
datasets and artifacts. The `default-editor` service account is auto-created by
Kubeflow's profile controller when the `aibplus-profile` Profile is created.

| Namespace          | Service Account  | IAM Role                              |
|--------------------|------------------|---------------------------------------|
| `aibplus-profile`  | `default-editor` | `aibplus-<market>-mlrun-runtime-role` |

```bash
aws eks create-pod-identity-association \
  --cluster-name <CLUSTER_NAME> \
  --region <REGION> \
  --namespace aibplus-profile \
  --service-account default-editor \
  --role-arn arn:aws:iam::<ACCOUNT_ID>:role/aibplus-<market>-mlrun-runtime-role
```

> **Note**: The `aibplus-profile` namespace and `default-editor` SA are created by
> the Kubeflow profile controller. The Pod Identity association can be created
> before or after — EKS will match it once both the namespace and SA exist.

### 3.5 ECR Token Generator

Allows the CronJob to generate ECR auth tokens for Nuclio image pushes.

| Namespace          | Service Account    | IAM Role                          |
|--------------------|--------------------|-----------------------------------|
| `external-secrets` | `external-secrets` | `aibplus-<market>-ecr-push-role`  |

> If the ECR token generator runs under the same `external-secrets` SA that
> already has the secrets-role association, you can either:
> - Add ECR permissions to the secrets role, or
> - Create a dedicated SA for the CronJob with its own association.

---

## 4. Verification

After creating all associations, verify them:

```bash
# List all associations for the cluster
aws eks list-pod-identity-associations \
  --cluster-name <CLUSTER_NAME> \
  --region <REGION> \
  --output table

# Test from a pod (example: MLRun API)
kubectl exec -n aib-system deploy/mlrun-api-chief -- \
  python3 -c "import boto3; print(boto3.client('sts').get_caller_identity()['Arn'])"

# Test from a notebook pod
kubectl exec -n aibplus-profile <notebook-pod-name> -- \
  python3 -c "import boto3; s3 = boto3.client('s3'); print(s3.list_buckets()['Buckets'])"
```

---

## 5. Helm Values Configuration for AWS

The shared charts (used for both GCP and AWS) require specific AWS overrides to
work correctly with Pod Identity and AWS Secrets Manager.

### 5.1 External Secrets Operator (`values/charts/AWS/external-secrets.yaml`)

The external-secrets chart creates the `external-secrets` service account used by
the ESO controller. For Pod Identity, **no SA annotations are needed** — the
association is handled at the EKS API level (see section 3.1).

Key settings:

```yaml
serviceAccount:
  name: external-secrets       # Must match the Pod Identity association SA name

# Images must point to your ECR mirror
image:
  repository: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aibplus-images/external-secrets
webhook:
  image:
    repository: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aibplus-images/external-secrets
certController:
  image:
    repository: <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aibplus-images/external-secrets
```

> **Do NOT** add `eks.amazonaws.com/role-arn` annotations — Pod Identity ignores them.
> If a stale GCP annotation (`iam.gke.io/gcp-service-account`) exists on the SA
> from a previous deployment, remove it:
> ```bash
> kubectl annotate sa external-secrets -n external-secrets iam.gke.io/gcp-service-account-
> ```

### 5.2 Central Secret Operator (`values/charts/AWS/central-secret-operator.yaml`)

This chart creates the `ClusterSecretStore` and all `ExternalSecret` resources.

Key settings:

```yaml
serviceAccount:
  create: false                # SA is created by the external-secrets chart (5.1)
  name: external-secrets       # Must match the SA from the external-secrets chart
  namespace: external-secrets

googleCloud:
  enabled: false               # Disable GCP Secret Manager provider

aws:
  enabled: true
  authMethod: podIdentity      # Use Pod Identity (not irsa)
  setupIAM:
    enabled: false             # IAM is managed externally (section 2)
    region: <REGION>           # Must match the Secrets Manager region
```

**Critical: Do NOT use `version: latest` in secret remoteRefs for AWS.**

The `version` field in ExternalSecret `remoteRef` maps to the AWS Secrets Manager
`VersionStage` parameter. `latest` is a GCP Secret Manager concept — AWS uses
`AWSCURRENT` (the default). Passing `version: latest` causes AWS to return
`ResourceNotFoundException` ("Secret does not exist").

The chart template (`eso-all-secrets.yaml`) has been updated to make the `version`
field conditional — it is only rendered when explicitly set in values. This means:
- **GCP values**: Keep `version: latest` (valid for GCP Secret Manager)
- **AWS values**: Omit `version` entirely (AWS defaults to `AWSCURRENT`)

Example AWS secret entry (no `version` field):

```yaml
secrets:
  - name: eso-dex-secret
    namespace: aib-auth
    targetName: dex-secret
    targetType: Opaque
    refreshInterval: 1h
    data:
      - secretKey: DEX_OAUTH2_PROXY_CLIENT_ID
        remoteRef:
          key: aibplus/deployment/dex-secret
          property: DEX_OAUTH2_PROXY_CLIENT_ID
          # version: omitted — AWS defaults to AWSCURRENT
```

### 5.3 AWS Secrets Manager — Secret Naming

All secrets referenced in the CSO values must exist in AWS Secrets Manager in the
same region as configured in `aws.setupIAM.region`. Each secret is a JSON object
whose keys match the `property` fields in the ExternalSecret `remoteRef`.

Required secrets:

| Secret Name                                  | Properties (JSON keys)                                                                                  |
|----------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `aibplus/deployment/oauth2-proxy-secret`     | `OAUTH2_PROXY_CLIENT_ID`, `OAUTH2_PROXY_CLIENT_SECRET`, `OAUTH2_PROXY_COOKIE_SECRET`                   |
| `aibplus/deployment/dex-secret`              | `DEX_OAUTH2_PROXY_CLIENT_ID`, `DEX_OAUTH2_PROXY_CLIENT_SECRET`, `DEX_OIDC_CLIENT_ID`, `DEX_OIDC_CLIENT_SECRET` |
| `aibplus/deployment/mysql-credentials`       | `mysql-root-password`, `mysql-replication-password`, `mysql-password`, `KUBEFLOW_DB_PASSWORD`, `MLRUN_DB_PASSWORD` |
| `aibplus/deployment/mysql-secret`            | `username`, `password`                                                                                  |
| `aibplus/deployment/mlpipeline-minio-artifact` | `accesskey`, `secretkey`                                                                              |
| `aibplus/deployment/mlrun-db`                | `dsn`, `oldDsn`                                                                                        |
| `aibplus/deployment/mlrun-redis-credentials` | `MLRUN_REDIS__URL`, `REDIS_USER`, `REDIS_PASSWORD`                                                     |
| `aibplus/deployment/redis-credentials`       | `redis-password`                                                                                        |

### 5.4 Debugging ESO on AWS

```bash
# Check ClusterSecretStore status
kubectl get clustersecretstore

# Check all ExternalSecrets
kubectl get externalsecrets -A

# Get detailed error for a failing ExternalSecret
kubectl describe externalsecret <name> -n <namespace>

# Check ESO controller logs
kubectl logs -n external-secrets deploy/external-secrets --tail=100

# Test Pod Identity from the ESO pod
kubectl run test-aws --rm -it --restart=Never \
  --image=<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aibplus-images/aws-cli:2.17.16 \
  --overrides='{"spec":{"serviceAccountName":"external-secrets"}}' \
  -n external-secrets \
  -- sts get-caller-identity

# Test secret access
kubectl run test-aws --rm -it --restart=Never \
  --image=<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/aibplus-images/aws-cli:2.17.16 \
  --overrides='{"spec":{"serviceAccountName":"external-secrets"}}' \
  -n external-secrets \
  -- secretsmanager get-secret-value \
  --secret-id aibplus/deployment/dex-secret \
  --region <REGION>
```

Common errors and causes:

| Error                      | Cause                                                        |
|----------------------------|--------------------------------------------------------------|
| "Secret does not exist"    | `version: latest` in remoteRef OR secret not in Secrets Manager |
| `AccessDeniedException`    | IAM role lacks `secretsmanager:GetSecretValue`               |
| "Unable to locate credentials" | Pod Identity association missing or agent not installed   |
| `UnrecognizedClientException`  | Pod Identity agent not running                           |

---

## 6. Summary Table — Pod Identity Associations

| # | Namespace          | Service Account    | IAM Role                     | Access Needed               |
|---|--------------------|--------------------|------------------------------|-----------------------------|
| 1 | `external-secrets` | `external-secrets` | `...-secrets-role`           | Secrets Manager             |
| 2 | `aib-system`       | `mlrun-api`        | `...-mlrun-runtime-role`     | S3 (artifacts, logs)        |
| 3 | `aib-system`       | `mlrun-job-runner` | `...-mlrun-runtime-role`     | S3 (training data, models)  |
| 4 | `aibplus-profile`  | `default-editor`   | `...-mlrun-runtime-role`     | S3 (notebooks, datasets)    |
| 5 | `external-secrets` | `external-secrets` | `...-ecr-push-role` (merge)  | ECR (token generation)      |
