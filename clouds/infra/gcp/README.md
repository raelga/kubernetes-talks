# Google Cloud: Terraform-managed GKE in Asia

Follow the [execution guide](../../RUNBOOK.md) for the demonstration and [detailed preparation](../../RUNBOOK-DETAILED.md#personal-gcp-identity-only) for the complete individually explained credential configuration. Run commands from the project root. Terraform owns the network, subnet, cluster and node pool; do not create/delete them separately with gcloud.

## Configuration

| Setting | Current value |
|---|---|
| Terraform root | `infra/gcp` |
| Personal account / project | `me@rael.io` / `bcncloud-gke` |
| Region / zone | `asia-northeast1` / `asia-northeast1-a`, Asia |
| Cluster | `clouds-gke` |
| Kubernetes | `1.36.4-gke.2326000` |
| Worker | One `e2-medium`, 30 GB boot disk |
| Network | Dedicated VPC/subnet with separate Pod and Service ranges |
| API | Public IPv4 `0.0.0.0/0` by default; optional `cluster_api_allowed_cidrs` override |
| kubectl context | `gke` |

This zonal single-worker demo is not production HA. Keep one app replica in the single `guestbook` Deployment on its 940m-allocatable worker; local Redis requests 25m CPU/64Mi. Do not add capacity, resize or change paid plans. Both modes use the same stable LoadBalancer Service (`app=guestbook`) and digest-pinned public Docker Hub image. Configure Cloudflare once; mode rollouts do not change origins. Existing differently named apps are not renamed here: migration requires separate approval, new Service addresses and a one-time origin update. No live deployment is authorized. Local messages are not migrated to D1.

## Personal credentials and prerequisites

**Only personal `me@rael.io` and project `bcncloud-gke` are allowed. Never use Red Hat/work identities, tools, ADC, projects or quota projects. Do not run application-default login or replace machine ADC.** The earlier 403 came from work ADC, not a missing personal role.

Install [Google Cloud CLI](https://cloud.google.com/sdk/docs/install), compatible [kubectl](https://kubernetes.io/docs/tasks/tools/), Terraform `>= 1.9, < 2.0` and the [gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl). Billing, Compute and GKE APIs must already be enabled in the personal project; this root does not manage project creation/billing/API enablement. Ask before billing changes. The personal identity needs network, cluster/node-pool and node-service-account permissions; verify regional quota and supported versions.

Use the detailed preparation's explicit personal CLI settings, cleared credential-file/impersonation overrides, disabled GKE ADC use and personal quota project. Authenticate if needed:

```bash
gcloud auth login me@rael.io
```

After those shell settings are in place, acquire/refresh the explicit short-lived personal Terraform token without printing it:

```bash
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token --account=me@rael.io)"
```

Inspect the effective shell-selected account and personal-project prerequisites. Do not infer the effective account from a different stored credential marked active.

```bash
gcloud config get-value account
gcloud billing projects describe bcncloud-gke --account=me@rael.io
gcloud services list --enabled --project=bcncloud-gke --account=me@rael.io
gcloud container get-server-config --zone=asia-northeast1-a --project=bcncloud-gke --account=me@rael.io
```

## Review a plan

The temporary demo API is deliberately public; authentication and Kubernetes RBAC remain required. Run `unset TF_VAR_cluster_api_allowed_cidrs` to clear the old environment override. Private tfvars and command-line inputs can still override the default; see [API access and precedence](../../RUNBOOK-DETAILED.md#demo-api-access). Keep existing local state/backups and checked-in lockfile. Do not run `init -upgrade`, start empty replacement state or commit plans/state/tokens.

```bash
cd infra/gcp
terraform init -lockfile=readonly
terraform plan
```

Review the personal project, region, versions, worker count, API allowlist and every replacement/deletion. Only apply intended changes after required approval:

```bash
terraform apply
cd ../..
```

Interactive apply presents a fresh plan for confirmation; review it before typing `yes`. The declared configuration removes GKE's temporary default pool and creates the intended pool; do not manage these pools manually.

## Kubeconfig and readiness

Keep personal shell settings for the auth plugin, which invokes gcloud. Use explicit context and account/project flags:

```bash
gcloud container clusters get-credentials clouds-gke --location=asia-northeast1-a --project=bcncloud-gke --account=me@rael.io
kubectl config set-context gke --cluster=gke_bcncloud-gke_asia-northeast1-a_clouds-gke --user=gke_bcncloud-gke_asia-northeast1-a_clouds-gke
kubectl --context gke wait --for=condition=Ready nodes --all --timeout=5m
kubectl --context gke get nodes -o wide
kubectl --context gke -n kube-system rollout status deployment/kube-dns --timeout=5m
kubectl --context gke -n kube-system get pods
```

One Ready worker and healthy DNS are required, but not sufficient for application/public-endpoint acceptance. Continue in the execution guide.

## Troubleshooting and evidence

- **403:** restore the explicit unexpired personal token. Never grant work identities lab roles or switch to work ADC.
- **Missing auth plugin:** install using the linked GKE instructions; component-managed SDKs use their component installer, package-managed SDKs use the matching package.
- **API timeout:** inspect connectivity, cluster health, credentials and any private CIDR override. Kubeconfig retrieval does not change authorized networks.
- **Pending Pods:** the worker has 940m allocatable CPU. The historical baseline requested 828m before the 25m Redis. Keep one app replica and zero rollout surge; expect a brief single-replica rollout gap. Wait for completion before demonstrating. Do not resize to hide scheduling issues.
- **Version/capacity unavailable:** check regional support and quota; location changes can replace the cluster and must preserve the coordinated four-continent design.
- **Interrupted creation:** retain original state. The historical interruption left a temporary `default-pool`, reconciled through a private single-resource Terraform recovery root before creating the intended pool; this is evidence, not an instruction to delete an arbitrary pool.

The historical successful cluster-only apply took about 12 minutes; the 2026-10-21 worker Ready time was 08:40:22 UTC. Earlier three-example app/global checks and stateful Pod-replacement persistence passed; public load-balancer convergence lagged Pod readiness, so the exact replacement process was verified rather than accepting fallback. These observations are not timing guarantees or a substitute for [two-example proof](../../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21). See [historical rehearsal](../../RUNBOOK-DETAILED.md#live-rehearsal--2026-10-21).

## Approved teardown (optional advanced saved-plan reference)

Follow [cleanup](../../RUNBOOK-DETAILED.md#cleanup) only after explicit approval. Remove routing, delete stable app resources once, remove scoped generated configuration and separately approved legacy names; do not blindly delete both overlapping overlays. Verify provider-side app load-balancer/forwarding-rule/IP/volume release while controllers run before Terraform destruction. Preserve the personal project, billing setup, shared registry and unrelated resources.

Refresh the personal token and review intended API inputs first, using the same state and personal shell settings. Review the destructive plan:

```bash
terraform -chdir=infra/gcp plan -destroy -out=destroy.tfplan
terraform -chdir=infra/gcp show destroy.tfplan
```

After reviewing and approving every deletion:

```bash
terraform -chdir=infra/gcp apply destroy.tfplan
terraform -chdir=infra/gcp state list
```

Verify provider-side removal of lab cluster, worker VMs/disks, subnet and network; retain state/backups until verified cleanup. Do not delete the project or its billing configuration. See the [infrastructure index](../README.md).
