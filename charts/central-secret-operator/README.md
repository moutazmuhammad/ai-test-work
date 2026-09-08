# Central Secret Operator (CSO)

Helm chart that manages all product Kubernetes secrets via External Secrets Operator (ESO). It syncs secrets from cloud secret managers (GCP Secret Manager / AWS Secrets Manager) into the cluster using ExternalSecret resources.

---

## Prerequisites

### Common (All Platforms)

- Helm v3.0+
- External Secrets Operator (ESO) installed (see `charts/external-secrets`)
- Required namespaces created before installation

---

### Google Cloud (GKE)

#### 1. Namespaces

Create the following namespaces:

```bash
kubectl create ns argocd
kubectl create ns aib-auth
kubectl create ns aib-data
kubectl create ns aib-system
kubectl create ns gateway
kubectl create ns aibplus-profile
```

#### 2. IAM Service Account

Create a GCP Service Account and grant it access to Secret Manager:

```bash
gcloud iam service-accounts create <sa-name> --project=<project-id>

gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:<sa-name>@<project-id>.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

#### 3. Workload Identity Binding

Bind the GCP SA to the Kubernetes SA (`eso-service-account` in `default` namespace):

```bash
gcloud iam service-accounts add-iam-policy-binding \
  <sa-name>@<project-id>.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:<project-id>.svc.id.goog[default/eso-service-account]"
```

#### 4. Secrets in GCP Secret Manager

The following secrets must exist in the target project:

| Category | Secret Names |
|----------|-------------|
| ArgoCD | `argocd-agent-ca`, `argocd-agent-client-tls` |
| OAuth2 / Dex | `oauth2-proxy-secret`, `dex-secret` |
| MySQL | `mysql-credentials`, `mysql-secret` |
| Object Storage | `mlpipeline-minio-artifact`, `minio-credentials` |
| SeaweedFS | `seaweedfs-admin-credentials`, `seaweedfs-db-credentials`, `seaweedfs-s3-config` |
| MLRun | `mlrun-db`, `mlrun-redis-credentials` |
| Redis | `redis-credentials` |
| Nuclio | `nuclio-push` |
| TLS Certificates | One per DNS subdomain (e.g. `kubeflow_dev_plus_aib_vodafone_com-tls-secret`) |

#### 5. Verification

```bash
gcloud iam service-accounts list --project=<project-id>
gcloud secrets list --project=<project-id>
```

---

### AWS (EKS)

#### 1. Namespaces

Create the following namespaces:

```bash
kubectl create ns external-secrets
kubectl create ns aib-auth
kubectl create ns aib-data
kubectl create ns aib-system
```

#### 2. EKS Pod Identity Agent

Install the addon on the cluster:

```bash
aws eks create-addon --cluster-name <cluster> --addon-name eks-pod-identity-agent --region <region>
```

Verify it is active:

```bash
aws eks describe-addon --cluster-name <cluster> --addon-name eks-pod-identity-agent --region <region> --query 'addon.status'
# Expected: "ACTIVE"
```

#### 3. IAM Role

Create a role with a trust policy for `pods.eks.amazonaws.com`:

```bash
aws iam create-role --role-name <role-name> --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": "sts:AssumeRole",
      "Condition": { "StringEquals": { "aws:SourceAccount": "<account-id>" } }
    },
    {
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": "sts:TagSession"
    }
  ]
}'
```

#### 4. IAM Policy

Create and attach a policy with Secrets Manager and ECR permissions:

```bash
aws iam create-policy --policy-name <policy-name> --policy-document '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecretsManager",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:<region>:<account-id>:secret:*"
    },
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPull",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "arn:aws:ecr:<region>:<account-id>:repository/*"
    }
  ]
}'

aws iam attach-role-policy \
  --role-name <role-name> \
  --policy-arn arn:aws:iam::<account-id>:policy/<policy-name>
```

#### 5. Pod Identity Associations

Two associations are required — one for ESO to read secrets, one for the ECR token CronJob:

```bash
# ESO controller — reads secrets from AWS Secrets Manager
aws eks create-pod-identity-association \
  --cluster-name <cluster> --region <region> \
  --namespace external-secrets --service-account external-secrets \
  --role-arn arn:aws:iam::<account-id>:role/<role-name>

# ECR token generator — fetches ECR login tokens for Nuclio image push
aws eks create-pod-identity-association \
  --cluster-name <cluster> --region <region> \
  --namespace external-secrets --service-account ecr-token-generator \
  --role-arn arn:aws:iam::<account-id>:role/<role-name>
```

#### 6. Secrets in AWS Secrets Manager

The following secrets must exist in the configured region under the `aibplus/` prefix:

| Category | Secret Names |
|----------|-------------|
| OAuth2 / Dex | `aibplus/oauth2-proxy-secret`, `aibplus/dex-secret` |
| MySQL | `aibplus/mysql-credentials`, `aibplus/mysql-secret` |
| Object Storage | `aibplus/mlpipeline-minio-artifact` |
| MLRun | `aibplus/mlrun-db`, `aibplus/mlrun-redis-credentials` |
| Redis | `aibplus/redis-credentials` |

#### 7. ECR Images

The following images must be pushed to the private ECR registry:

- `<account-id>.dkr.ecr.<region>.amazonaws.com/aibplus-images/aws-cli:<tag>`
- `<account-id>.dkr.ecr.<region>.amazonaws.com/aibplus-images/bitnami-kubectl:<tag>`

#### 8. Verification

```bash
aws iam list-attached-role-policies --role-name <role-name>
aws eks list-pod-identity-associations --cluster-name <cluster> --region <region>
aws secretsmanager list-secrets --region <region> --query 'SecretList[].Name'
aws ecr describe-images --repository-name aibplus-images/aws-cli --region <region> --query 'imageDetails[].imageTags'
```

---

## Installation

### 1. Configure Provider

Enable your cloud provider in the values file:

**GKE:**
```yaml
googleCloud:
  enabled: true
  setupIAM:
    enabled: false
    serviceAccountName: "google-service-account"
    projectId: "your-project-id"
```

**EKS:**
```yaml
aws:
  enabled: true
  authMethod: podIdentity
  setupIAM:
    enabled: false
    region: "your-region"
    accountId: "your-account-id"
    iamRoleArn: "arn:aws:iam::<account-id>:role/<role-name>"
```

### 2. Deploy

```bash
helm install central-secrets-operator ./central-secrets-operator -f values.yaml
helm upgrade central-secrets-operator ./central-secrets-operator -f values.yaml
```

---

## Managing Secrets

Add entries to the `secrets` list in values.yaml. Each entry creates an ExternalSecret that syncs from the cloud secret manager:

```yaml
secrets:
  - name: eso-oauth2-proxy-secret
    namespace: aib-auth
    targetName: oauth2-proxy-secret
    targetType: Opaque
    refreshInterval: 1h
    data:
      - secretKey: OAUTH2_PROXY_CLIENT_ID
        remoteRef:
          key: oauth2-proxy-secret
          property: OAUTH2_PROXY_CLIENT_ID
          version: latest
```

Secrets are templated via `eso-all-secrets.yaml` and can be extended per platform.
