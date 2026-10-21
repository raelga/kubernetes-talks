# Execution guide

Run from the project root in one prepared terminal, one command at a time. For errors, use the [detailed reference](RUNBOOK-DETAILED.md).

Terraform manages infrastructure and routing; Kubernetes YAML/Kustomize manages the applications. Use demo data only.

## 1. Prepare

This guide assumes fresh clusters. After a previous run, follow the [approved cleanup procedure](RUNBOOK-DETAILED.md#cleanup) first; keep Terraform state intact.

Complete [preparation](RUNBOOK-DETAILED.md#preparation): credentials, tools and Terraform state. The `demo-v2` image is pinned in `k8s/base/kustomization.yaml`; no rebuild is needed. The `local` and `shared` variants inherit this base.

Terraform and Kustomize both read `STATE_API_TOKEN` directly from ignored `k8s/shared/credentials.env`. Keep the existing file; no application-token export or Terraform variable is needed.

### Verify your accounts

```bash
aws sts get-caller-identity
az account show --query '{name:name,id:id,user:user.name}' -o json
gcloud config get-value account
gcloud config get-value project
doctl account get
```

Confirm the intended AWS and DigitalOcean accounts, Azure subscription `k8s-talk` / `c825038c-1551-4ccf-8ddd-24b49f8e14b4`, and GCP account `me@rael.io` with project `bcncloud-gke`. Use personal GCP credentials only, not work identities or ADC. Refresh Terraform's access token:

```bash
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token --account=me@rael.io)"
```

Refresh the short-lived GCP token before later operations as needed. Billing/API enablement and subscription billing changes need explicit approval.

## 2. Create the clusters

All four Kubernetes APIs default to public IPv4 access (`0.0.0.0/0`). This is deliberate temporary demo exposure, not a production setup. Kubernetes authentication and RBAC still apply. Private variable files can override Terraform defaults; review the effective plan.

For each Terraform directory, run `init` and `plan`, review changes and costs, then obtain approval before `apply`. Interactive `terraform apply` replans: review the actual changes at the `yes` prompt before approving. Run `cd ../..` only after success. Keep state intact.

### AWS — North America

Use `us-east-1`.

```bash
cd infra/aws
terraform init
terraform plan
```

Confirm `clouds-eks`, the intended account/region, one worker and public API access, then apply:

```bash
terraform apply
cd ../..
```

### Azure — Europe

Use `westeurope` in the selected subscription.

```bash
cd infra/azure
terraform init
terraform plan
```

Confirm `clouds-aks`, resource group `clouds-aks-rg`, the intended subscription, one worker and public API access, then apply:

```bash
terraform apply
cd ../..
```

### Google Cloud — Asia

Use only the personal GCP project and credentials.

```bash
cd infra/gcp
terraform init
terraform plan
```

Confirm `clouds-gke`, project `bcncloud-gke`, zone `asia-northeast1-a`, one worker and public API access, then apply:

```bash
terraform apply
cd ../..
```

### DigitalOcean — Oceania

Use `syd1`, one worker and the default non-HA control plane.

```bash
cd infra/digitalocean
terraform init
terraform plan
```

Confirm `clouds-doks`, one worker, public API access and the intended HA setting, then apply:

```bash
terraform apply
cd ../..
```

## 3. Connect to all four clusters and check readiness

Fetch current credentials every run, even if these local aliases already exist: `eks`, `aks`, `gke` and `doks`.

### AWS / EKS

```bash
aws eks update-kubeconfig --region us-east-1 --name clouds-eks --alias eks
kubectl --context eks wait --for=condition=Ready nodes --all --timeout=5m
kubectl --context eks -n kube-system rollout status daemonset/aws-node --timeout=5m
kubectl --context eks -n kube-system rollout status deployment/coredns --timeout=5m
```

### Azure / AKS

```bash
az aks get-credentials --resource-group clouds-aks-rg --name clouds-aks --subscription c825038c-1551-4ccf-8ddd-24b49f8e14b4 --context aks --overwrite-existing
kubectl --context aks wait --for=condition=Ready nodes --all --timeout=5m
kubectl --context aks -n kube-system rollout status deployment/coredns --timeout=5m
```

### Google Cloud / GKE

```bash
gcloud container clusters get-credentials clouds-gke --location=asia-northeast1-a --project=bcncloud-gke --account=me@rael.io
kubectl config set-context gke --cluster=gke_bcncloud-gke_asia-northeast1-a_clouds-gke --user=gke_bcncloud-gke_asia-northeast1-a_clouds-gke
kubectl --context gke wait --for=condition=Ready nodes --all --timeout=5m
kubectl --context gke -n kube-system rollout status deployment/kube-dns --timeout=5m
```

### DigitalOcean / DOKS

```bash
cd infra/digitalocean
export DOKS_CLUSTER_ID="$(terraform output -raw cluster_id)"
cd ../..
doctl kubernetes cluster kubeconfig save "$DOKS_CLUSTER_ID" --alias doks
kubectl --context doks wait --for=condition=Ready nodes --all --timeout=5m
kubectl --context doks -n kube-system rollout status deployment/konnectivity-agent --timeout=5m
```

Continue when workers are Ready and the system rollouts succeed.

## 4. Deploy Local datastore directly

Deploy the same UI/image with `APP_MODE=local` and Redis. Both modes use one `guestbook` Deployment and LoadBalancer Service per cluster (`app=guestbook`); changing mode rolls the Deployment, not the Service.

For each `get pods -w`, wait until all desired app and Redis containers are READY, then press Ctrl+C to continue. The watch does not exit automatically. During mode changes, old and new modes may temporarily coexist; the rollout-status command waits until old app Pods are gone.

### AWS / EKS

```bash
kubectl --context eks apply -k k8s/overlays/aws/local
kubectl --context eks get pods -w
kubectl --context eks get service guestbook -o wide
```

### Azure / AKS

```bash
kubectl --context aks apply -k k8s/overlays/azure/local
kubectl --context aks get pods -w
kubectl --context aks get service guestbook -o wide
```

### Google Cloud / GKE

```bash
kubectl --context gke apply -k k8s/overlays/gcp/local
kubectl --context gke get pods -w
kubectl --context gke get service guestbook -o wide
```

### DigitalOcean / DOKS

```bash
kubectl --context doks apply -k k8s/overlays/digitalocean/local
kubectl --context doks get pods -w
kubectl --context doks get service guestbook -o wide
```

Wait for Redis/app rollouts and each `guestbook` Service's public `EXTERNAL-IP` (AWS may return a hostname). Keep these same Services through the local/shared demonstration.

## 5. Configure HTTPS origins once

Get each app Service's public address from the project root:

```bash
kubectl --context eks get service guestbook -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}'
kubectl --context aks get service guestbook -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --context gke get service guestbook -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --context doks get service guestbook -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
```

Copy the outputs into ignored `infra/cloudflare/origins.auto.tfvars` using the structure below. Use the AWS hostname, not its resolved IPs. Omit schemes, paths and ports. Leave `""` for providers that are not ready; empty values are ignored.

```hcl
origin_addresses = {
  aws          = "<actual AWS guestbook Service hostname>"
  azure        = "<actual Azure guestbook Service IP>"
  gcp          = "<actual GCP guestbook Service IP>"
  digitalocean = "<actual DigitalOcean guestbook Service IP>"
}
```

Keep all four provider keys in this file. Prerequisite: one Cloudflare API token with **Workers Scripts Edit and D1 Edit** on the intended account, plus **Zone Read, DNS Edit and Workers Routes Edit** on `rael.dev`. Load it privately as exported `CLOUDFLARE_API_TOKEN`; Terraform reads that standard variable directly.

```bash
export TF_VAR_account_id="${CLOUDFLARE_ACCOUNT_ID:?Load your Cloudflare account ID privately}"
```

```bash
cd infra/cloudflare
terraform init
terraform plan
```

Confirm the account, zone, `guestbook.rael.dev`, Worker/D1 resources and configured origins, then apply. Terraform manages DNS-only aliases for nonempty IP origins.

```bash
terraform apply
cd ../..
```

Wait for working DNS and TLS before continuing.

## 6. Show exact routing and local isolation

The cookie selects the origin; the explicit lab User-Agent avoids ambiguous generic-client routing.

```bash
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=aws' https://guestbook.rael.dev/api/deployment
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=azure' https://guestbook.rael.dev/api/deployment
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=gcp' https://guestbook.rael.dev/api/deployment
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=digitalocean' https://guestbook.rael.dev/api/deployment
```

Each response should have valid TLS, HTTP 200, matching `X-Lab-Origin` and JSON `provider`, `mode: local`, and `storage: redis`; a fallback is not the selected route.

Open `https://guestbook.rael.dev` and show **Local datastore** with provider/region/Pod branding. In browser developer tools, set `clouds_origin=aws` for this hostname and path `/`. Write a unique message and reload across AWS replicas. Select `azure`, `gcp` and `digitalocean` in turn: the AWS message stays absent. Write a different local message in each, then return to AWS to show its original message.

Redis is cluster-local and replacement can lose messages. GET/HEAD wait at most 2 seconds for each origin's response headers before failover; POST is sent only once. Optionally clear the cookie to demonstrate geographic selection.

## 7. Deploy Shared datastore

Roll the same `guestbook` Deployment to `APP_MODE=shared` and the Worker/D1 backend. Local Redis messages are not migrated. Local and Shared Pods may briefly coexist behind the same Service: finish every rollout and wait for all desired replicas Ready before demonstrating Shared datastore. The Service addresses and Cloudflare origins do not change.

### AWS / EKS

```bash
kubectl --context eks apply -k k8s/overlays/aws/shared
kubectl --context eks get pods -w
kubectl --context eks rollout status deployment/guestbook --timeout=5m
```

### Azure / AKS

```bash
kubectl --context aks apply -k k8s/overlays/azure/shared
kubectl --context aks get pods -w
kubectl --context aks rollout status deployment/guestbook --timeout=5m
```

### Google Cloud / GKE

```bash
kubectl --context gke apply -k k8s/overlays/gcp/shared
kubectl --context gke get pods -w
kubectl --context gke rollout status deployment/guestbook --timeout=5m
```

### DigitalOcean / DOKS

```bash
kubectl --context doks apply -k k8s/overlays/digitalocean/shared
kubectl --context doks get pods -w
kubectl --context doks rollout status deployment/guestbook --timeout=5m
```

Wait for all four rollouts to complete with all desired replicas Ready and old Local app Pods gone. Keep the stable `guestbook` Services, local Redis and `k8s/shared/credentials.env`/Worker credential. No second origin collection or Cloudflare Terraform apply is needed.

## 8. Show Shared datastore cross-provider reads

Check the app-to-D1 path through every provider:

```bash
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=aws' https://guestbook.rael.dev/api/deployment
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=azure' https://guestbook.rael.dev/api/deployment
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=gcp' https://guestbook.rael.dev/api/deployment
curl -i --max-time 30 -H 'User-Agent: clouds-lab/1.0' -H 'Cookie: clouds_origin=digitalocean' https://guestbook.rael.dev/api/deployment
```

Each response should have HTTP 200, exact requested `X-Lab-Origin` and JSON `provider`, `mode: shared`, and `storage: d1`. A fallback or direct `/state/messages` response does not show the app-to-D1 path.

In the browser, select AWS and show **Shared datastore** with AWS branding. Write a unique message, then select Azure, GCP and DigitalOcean: the same ID, text and writer metadata remain visible. Write through another provider and read it through AWS after a reload.

Local messages are not migrated. Shared datastore uses Cloudflare-hosted D1, not a database replicated across the four Kubernetes providers.

Keep Terraform states private. [Cleanup](RUNBOOK-DETAILED.md#cleanup) is destructive and requires explicit approval; do not delete infrastructure automatically after the demo.
