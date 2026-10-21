# Four-cloud Guestbook: detailed operator reference

Use [RUNBOOK.md](RUNBOOK.md) for the human execution sequence. This document holds setup, ownership, recovery, cleanup and dated evidence. There is no session deadline or provisioning-time guarantee. Run commands from the project root in a Bash session; each command below is independent, not a script to paste wholesale.

## Ownership and constraints

| Owner / root | Resources / location | Current worker / version |
|---|---|---|
| [AWS](infra/aws/README.md), `infra/aws` | EKS `clouds-eks`, `us-east-1`, North America; VPC, IAM, addons | One `t3.medium`; Kubernetes `1.36` |
| [Azure](infra/azure/README.md), `infra/azure` | AKS `clouds-aks`, `westeurope`, Europe; lab resource group | One `Standard_B2s`; `1.36.4` |
| [GCP](infra/gcp/README.md), `infra/gcp` | GKE `clouds-gke`, `asia-northeast1-a`, Asia; dedicated VPC/subnet/pool | One `e2-medium`; `1.36.4-gke.2326000` |
| [DigitalOcean](infra/digitalocean/README.md), `infra/digitalocean` | DOKS `clouds-doks`, `syd1`, Oceania | One `s-2vcpu-4gb`; `1.36.5-do.1`; existing approved HA |
| [Cloudflare](infra/cloudflare/README.md), `infra/cloudflare` | Worker `clouds-global-router`, D1, `guestbook.rael.dev`, origin DNS aliases | Existing `rael.dev` zone; no paid-plan upgrade |
| [Docker Hub](infra/dockerhub/README.md), `infra/dockerhub` | Public `raelga/clouds-guestbook` repository | Shared preparation resource, retained across sessions |

Terraform owns infrastructure, with independent local state in each root. Never create the same resources manually through cloud CLIs, eksctl, CloudFormation or Wrangler deploy. Provider CLIs authenticate, retrieve kubeconfigs and inspect resources. Kubernetes YAML/Kustomize owns app Deployments, Services, generated ConfigMaps and Secrets; cloud controllers own the resulting application load balancers.

This repository-only cutover defines one `guestbook` Deployment and LoadBalancer Service per cluster with `app=guestbook` selectors. It does not change running `guestbook-local` / `guestbook-shared` resources or older `guestbook-stateless` / `guestbook-stateful` installations. Applying the new manifests does not rename those resources: it can create a parallel load balancer. Migration requires separate approval for [legacy cleanup](#legacy-names-from-the-running-installation), release verification, new Service addresses and a one-time Cloudflare update. Fresh clusters have no legacy cleanup gate. No deployment, teardown, token change, additional capacity or paid-plan change is authorized here. Retain approved DigitalOcean HA and existing provider prerequisites.

Both modes use the same UI and public `docker.io/raelga/clouds-guestbook:demo-v2` image, pinned by tag and OCI-index digest in `k8s/base/kustomization.yaml`. The base defines the common Deployment, Service and image; variants add storage configuration and provider overlays add location and replica counts. Local datastore shares one ephemeral Redis within each cluster. Shared datastore uses the existing Cloudflare Worker/D1; no data is migrated between modes. ConfigMaps remain `guestbook-local-location` / `guestbook-shared-location`, the shared Secret remains `guestbook-shared-state`, and Redis remains `guestbook-local-redis` with a ClusterIP Service. Switching variants rolls the same app Deployment; old and new modes may coexist briefly behind its stable Service. Wait for rollout completion, all desired replicas Ready and old Pods gone before demonstrating. Configure Cloudflare once; mode changes do not change origins. Use demo data only: origin HTTP and cluster-internal Redis are unencrypted.

## Preparation

### Tools and private inputs

Install Terraform `>= 1.9, < 2.0`, AWS CLI v2, Azure CLI, Google Cloud CLI with `gke-gcloud-auth-plugin`, doctl, a Kubernetes-1.36-compatible kubectl, curl and OpenSSL. Docker/buildx is needed only to publish a changed image. Node 22+ and npm are needed only for Wrangler OAuth or local Worker development; jq is used to capture OAuth's JSON token output safely. Follow provider installation links in the individual guides. Preserve checked-in Terraform lockfiles; do not use `init -upgrade` during execution.

Use a private terminal, not a recorded presentation, for credential entry. Values below are read interactively rather than embedded in shell history. Do not put secrets into committed files or ordinary tfvars. Shell exports do not change the declarative application configuration. If the shell is lost, restore these inputs and the same local states before continuing.

| Input | Consumer | Source / rule |
|---|---|---|
| `AWS_PROFILE` if used | AWS CLI and Terraform AWS provider | Intended authorized AWS deployment profile |
| Azure CLI login/subscription | AzureRM provider and kubeconfig retrieval | `k8s-talk`, `c825038c-1551-4ccf-8ddd-24b49f8e14b4` |
| `GOOGLE_OAUTH_ACCESS_TOKEN` | Terraform Google provider | Explicit personal `me@rael.io` CLI token only |
| `DIGITALOCEAN_TOKEN` | Terraform DigitalOcean provider | Existing private API token |
| `DIGITALOCEAN_ACCESS_TOKEN` | doctl | Same DigitalOcean credential |
| `CLOUDFLARE_API_TOKEN` | Cloudflare provider | One token with both account runtime and zone DNS edit permissions |
| `TF_VAR_account_id` | Cloudflare Terraform root | Intended existing account ID |
| `STATE_API_TOKEN` | Kustomize Secret input / Worker secret | Reuse ignored `k8s/shared/credentials.env` for existing lab |
| `TF_VAR_control_plane_ha` | DigitalOcean Terraform root | **`true` for current cluster**, `false` only for a fresh approved non-HA lab |
| `cluster_api_allowed_cidrs` (optional override) | AWS, Azure and GCP cluster roots | Defaults to `["0.0.0.0/0"]`; clear stale `TF_VAR_cluster_api_allowed_cidrs` |
| `control_plane_allowed_cidrs` (optional override) | DigitalOcean Terraform root | Independent input; defaults to `["0.0.0.0/0"]` |
| `origin_addresses` | Cloudflare Terraform root | Four real app Service endpoints in ignored `origins.auto.tfvars` |

Other provider inputs (names, regions, versions, Azure subscription, GCP project, Cloudflare zone/hostname, registry namespace) have defaults in each root's `variables.tf` or `main.tf`. Review the actual plan before changing any default. Any account, region, size, tier or replacement change needs approval, not a silent workaround.

### AWS and Azure

If using a named AWS profile, enter the intended profile name, then export it. Omit these two commands if your approved credential workflow already selects the intended identity.

```bash
read -r -p 'AWS deployment profile: ' AWS_PROFILE
export AWS_PROFILE
```

Complete your AWS profile's approved login/SSO workflow and confirm the account/principal before Terraform. This check does not prove create permissions.

```bash
aws sts get-caller-identity
```

Azure requires interactive MFA. Wait for login and its subscription-selection prompt to finish; do not reuse an expired device code.

```bash
az login --use-device-code
```

Select and confirm the required subscription explicitly. Terraform's subscription default is also this ID; selecting another CLI subscription does not override it.

```bash
az account set --subscription c825038c-1551-4ccf-8ddd-24b49f8e14b4
az account show --query '{name:name,id:id,state:state}' --output table
```

### Personal GCP identity only

**Only `me@rael.io` and `bcncloud-gke` are permitted. Never use Red Hat/work identities, tools, ADC, projects or quota projects. Do not run `gcloud auth application-default login` or replace machine ADC.** An earlier network-create 403 came from work ADC, not missing personal-account permissions.

Authenticate the personal CLI identity if it is not already available:

```bash
gcloud auth login me@rael.io
```

Clear credential-file and impersonation overrides in this shell so they cannot select another identity. This does not edit or delete stored credentials.

```bash
unset GOOGLE_APPLICATION_CREDENTIALS GOOGLE_CREDENTIALS GOOGLE_IMPERSONATE_SERVICE_ACCOUNT
unset GCLOUD_KEYFILE_JSON GOOGLE_CLOUD_KEYFILE_JSON
```

Pin the CLI identity and project for both direct commands and the GKE authentication plugin:

```bash
export CLOUDSDK_CORE_ACCOUNT=me@rael.io
export CLOUDSDK_CORE_PROJECT=bcncloud-gke
```

Disable ADC use by the GKE plugin and pin the personal quota project:

```bash
export CLOUDSDK_CONTAINER_USE_APPLICATION_DEFAULT_CREDENTIALS=false
export GOOGLE_CLOUD_QUOTA_PROJECT=bcncloud-gke
```

Acquire an explicit short-lived personal token for Terraform without printing it. Stop if token acquisition fails or returns empty. Refresh with this same command before later operations if it expires.

```bash
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token --account=me@rael.io)"
```

Inspect prerequisites using explicit personal account/project arguments. Billing and Compute/GKE APIs must already be enabled; ask before billing changes or API enablement, rather than changing them here.

```bash
gcloud billing projects describe bcncloud-gke --account=me@rael.io
gcloud services list --enabled --project=bcncloud-gke --account=me@rael.io
gcloud container get-server-config --zone=asia-northeast1-a --project=bcncloud-gke --account=me@rael.io
```

### DigitalOcean credentials and HA

Load the existing API token privately, then export it for Terraform and doctl. `read -s` hides terminal input; press Enter after pasting.

```bash
read -r -s -p 'DigitalOcean API token: ' DIGITALOCEAN_TOKEN
export DIGITALOCEAN_TOKEN
export DIGITALOCEAN_ACCESS_TOKEN="$DIGITALOCEAN_TOKEN"
```

For the **current existing cluster**, preserve approved HA explicitly before every plan, including destruction planning:

```bash
export TF_VAR_control_plane_ha=true
```

**Fresh creation only:** the Terraform default is non-HA. Only in a separately approved fresh lab with no existing HA cluster, choose this instead:

```bash
export TF_VAR_control_plane_ha=false
```

Kubernetes 1.36+ enables separately billed HA when `ha` is omitted; Terraform explicitly supplies this setting. The running cluster's approved HA price was $40/month, prorated hourly, additional to workers/load balancers; its worker catalog price was $24/month. Do not toggle the live cluster to test fresh-create behavior. Review replacements/tier changes and ask before any billing change.

HA is not required for this single-worker demonstration. Keep fresh clusters non-HA. [DigitalOcean does not allow disabling HA once enabled](https://docs.digitalocean.com/products/kubernetes/how-to/enable-high-availability/), so a non-HA replacement of the current cluster requires separate approval. A read-only downgrade plan showed an in-place update, but that does not override the API lifecycle restriction; do not apply it.

DigitalOcean uses independent optional `control_plane_allowed_cidrs`, defaulting to `["0.0.0.0/0"]`, like the other three demo APIs. The shared AWS/Azure/GCP CIDR environment variable cannot override it. Authentication and Kubernetes RBAC remain required.

Check account quota, Sydney versions and worker catalog. A catalog listing is not a reservation of live capacity. The inspected account had a three-Droplet limit; upgrades may require spare quota.

```bash
doctl account get
doctl kubernetes options regions
doctl kubernetes options versions
doctl kubernetes options sizes
doctl compute size list
doctl kubernetes cluster list
```

### Cloudflare runtime and DNS credentials are different concerns

Both permission sets are required, but one custom API token supplies them to a single Terraform provider. Prerequisite: **Workers Scripts Edit and D1 Edit** on the intended account, and **Zone Read, DNS Edit and Workers Routes Edit** on `rael.dev`. Restrict the token to those resources. It is not the application's `STATE_API_TOKEN`.

Load and export the combined token privately as `CLOUDFLARE_API_TOKEN`. The provider reads that standard variable directly; no token alias or mapping is needed. Set the account separately:

```bash
export TF_VAR_account_id="${CLOUDFLARE_ACCOUNT_ID:?Load your Cloudflare account ID privately}"
```

No separate DNS-token input or Wrangler OAuth session is required. Read-only zone, DNS, Workers and D1 checks succeeded for the existing token; its edit policies could not be inspected. Do not treat successful read requests as proof of edit permission. Account-scoped token verification uses the account-token endpoint, not the user-token endpoint.

The account/zone must be active; `guestbook.rael.dev` must have no conflicting ownership. See [Custom Domains requirements](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/). No domain registration, paid Load Balancing purchase or plan upgrade is included.

### Existing application token: reuse, never regenerate

Terraform and Kustomize both read ignored `k8s/shared/credentials.env` directly. It must contain exactly one `STATE_API_TOKEN=<nonempty token>` entry without whitespace in the token. Terraform resolves the file relative to its module, so this also works when invoked from `infra/cloudflare` or with `-chdir`. No `state_api_token` input variable, shell sourcing or application-token export is needed. The file is marked sensitive when read; do not print its contents or rewrite it.

If that existing file is missing, recover the original matching private input from its protected backup before proceeding. Do not generate a replacement: doing so would rotate the Worker credential and require coordinated app Secret updates/rollouts. Never put Cloudflare management credentials in this file or expose the token to browser JavaScript.

**New installation only, not the current lab:** if no application token, Worker or matching Secret input exists yet, generate a new token once. The command uses OpenSSL and captures the result without displaying it:

```bash
export STATE_API_TOKEN="$(openssl rand -hex 32)"
```

For that new installation only, set restrictive permissions for files subsequently created by this shell and write the shared credential input once:

```bash
umask 077
printf 'STATE_API_TOKEN=%s\n' "$STATE_API_TOKEN" > k8s/shared/credentials.env
```

`k8s/shared/kustomization.yaml` reads `credentials.env` through `secretGenerator`. Its ConfigMap declares `STATE_API_URL=https://guestbook.rael.dev`; app servers append `/state/messages` and verify TLS. Terminal exports do not override YAML. Generated hashes update Pod references and cause normal rollouts. Keep this file for future shared-overlay rendering and deployment. Never print rendered shared YAML; Secret data is only base64-encoded.

### Demo API access

All four Kubernetes APIs allow IPv4 `0.0.0.0/0` by default. This deliberate public exposure is for the temporary demo only; authentication and Kubernetes RBAC remain required. AWS, Azure and GCP use optional `cluster_api_allowed_cidrs`; DigitalOcean uses independent optional `control_plane_allowed_cidrs`. No operator-IP discovery or network-specific update is needed.

These are Terraform defaults, not evidence that every running API is already public. Only DigitalOcean's firewall change was previously applied and verified; AWS, Azure and GCP require a reviewed human apply to change their existing access settings.

Clear the old environment override before planning:

```bash
unset TF_VAR_cluster_api_allowed_cidrs
```

Private `terraform.tfvars`, `*.auto.tfvars` and explicit `-var`/`-var-file` inputs can still override these defaults. Auto tfvars override `TF_VAR_*`; command-line inputs override auto files. Review private inputs and the actual plan for retained restrictions. For a restrictive deployment, deliberately set approved CIDRs through the appropriate provider input.

### Isolated personal Docker Hub configuration

Skip image publication when using the already-pinned release. For publication, isolate personal Docker credentials from work configuration. Create a private directory and make Docker use it; this does not select a Docker daemon.

```bash
umask 077
export DOCKER_CONFIG="$HOME/.docker-clouds-personal"
mkdir -p "$DOCKER_CONFIG"
```

Check that buildx is available under this personal configuration:

```bash
docker buildx version
```

On this Apple Silicon/Homebrew workstation, a new credential directory may not discover the installed buildx plugin. Only if the check reports a missing plugin, expose the existing Homebrew binary once without replacing the credential file:

```bash
mkdir -p "$DOCKER_CONFIG/cli-plugins"
ln -s /opt/homebrew/lib/docker/cli-plugins/docker-buildx "$DOCKER_CONFIG/cli-plugins/docker-buildx"
docker buildx version
```

Choose the intended personal runtime independently; the current local runtime is the `global-review` Colima socket. Use its actual socket, not a work/Podman runtime. If it differs on another workstation, select that personal runtime instead.

```bash
export DOCKER_HOST="unix://$HOME/.colima/global-review/docker.sock"
docker login --username raelga
```

The Terraform Docker provider can instead use private `DOCKER_USERNAME` / `DOCKER_PASSWORD` environment variables. Do not mix a work login with the personal namespace. Review the [registry root](infra/dockerhub/README.md) before publication; the current repository is already tracked, so do not import it again. Retain the repository and its state when tearing down clusters.

For changed code, publish a new readable tag for both architectures, then record the published OCI-index digest in the base. `demo-v2` introduced `local` / `shared` mode names. The following commands document that publication; an already-pinned demo needs no rebuild.

```bash
export GUESTBOOK_IMAGE=docker.io/raelga/clouds-guestbook:demo-v2
docker buildx build --platform linux/amd64,linux/arm64 --tag "$GUESTBOOK_IMAGE" --push app/guestbook
docker buildx imagetools inspect "$GUESTBOOK_IMAGE"
```

Update `newTag` and `digest` in `k8s/base/kustomization.yaml`. Both variants and all clouds inherit the same image. Docker Hub anonymous pull limits apply; paid-plan changes need approval. ECR and cluster image-pull credentials are not required.

## Terraform planning and state retention

For normal execution, follow [RUNBOOK.md](RUNBOOK.md): enter each provider directory with `cd`, run `terraform init -lockfile=readonly`, inspect `terraform plan`, then run interactive `terraform apply` and review its fresh plan before confirming. Return to the repository root before application commands. Keep each root's existing state and checked-in lockfile; never initialize replacement state for existing resources.

### Optional advanced reference: exact saved plans

The saved-plan commands in this detailed reference are optional advanced workflows, not the main execution sequence. Saved plans contain inputs and potentially secrets; keep them private. Applying an exact saved plan runs without another confirmation and accepts no new `-var` inputs. Recreate and review it whenever inputs change.

Review accounts, locations, worker counts, API CIDRs, origins, D1 identity, HA and every create/update/delete/replacement. A reuse run should not create replacement clusters or load balancers. Preserve state and backups after interruptions; reconcile accepted cloud operations through a new Terraform plan rather than replaying an old creation plan or deleting state. Temporary private logs/plans are not substitutes for local Terraform state.

### Fresh-only Worker/D1 bootstrap

**Skip this section for the current existing Worker/D1.** For a separately approved first installation, empty origins allow the state API to exist before app Services. Frontend routing honestly returns 503 until four real origins are configured; do not invent endpoints. Prepare Cloudflare credentials and the new-only matching application token first.

An existing `infra/cloudflare/origins.auto.tfvars` takes precedence over environment variables. For this fresh-only bootstrap, explicitly override it in the plan rather than assuming `TF_VAR_origin_addresses='{}'` wins:

```bash
terraform -chdir=infra/cloudflare init -input=false -lockfile=readonly
terraform -chdir=infra/cloudflare plan -var='origin_addresses={}' -out=bootstrap.tfplan
terraform -chdir=infra/cloudflare show bootstrap.tfplan
```

After explicit approval of first-time billable resources and the reviewed account/zone/hostname/database, apply that exact plan:

```bash
terraform -chdir=infra/cloudflare apply bootstrap.tfplan
```

D1 creates the message table idempotently on first authenticated use. Keep the resulting D1 identity, token and original state for the later origin updates; this is not a disposable bootstrap database.

### Real origins and input precedence

Read each cluster's `guestbook` Service with an explicit context in the default namespace. Collect the **application** hostname/IP, never the Kubernetes API endpoint. Configure these stable origins once after Local datastore is ready; Shared datastore rolls the same Deployment behind the same Service and requires no routing update. A separately approved migration from differently named Services creates new addresses: collect them and replace stale origins once, never assume address preservation.

Maintain ignored `infra/cloudflare/origins.auto.tfvars` with all four provider keys and actual app Service addresses. Empty string values are ignored. The following is **HCL data, not a shell command**; omit schemes, paths and ports:

```hcl
origin_addresses = {
  aws          = "actual AWS application Service hostname"
  azure        = "actual Azure application Service IP"
  gcp          = "actual GCP application Service IP"
  digitalocean = "actual DigitalOcean application Service IP"
}
```

The normal routing plan automatically loads this file:

```bash
terraform -chdir=infra/cloudflare plan -out=demo.tfplan
terraform -chdir=infra/cloudflare show demo.tfplan
```

Review configured origins and expected Worker/DNS-only alias updates before applying. Empty values are skipped by the router and create no DNS aliases; with all values empty, frontend requests return 503 but authenticated state requests still work. Add each provider's address and apply again as its app becomes ready. For IP endpoints, Terraform creates address-hashed DNS-only A/AAAA aliases; AWS ELB hostnames are used directly. Clearing a previously configured IP removes its managed alias, not its Kubernetes Service or load balancer. Never replace unrelated DNS records or disable zone security.

Terraform precedence matters: defaults are overridden by `TF_VAR_*`, then `terraform.tfvars` / `*.auto.tfvars` files, then explicit `-var` / `-var-file` flags (later command-line values win). `unset TF_VAR_origin_addresses` removes a stale environment value but does not remove values in auto files. To make an environment-provided map override an auto file deliberately, pass it explicitly when planning:

```bash
terraform -chdir=infra/cloudflare plan -var="origin_addresses=$TF_VAR_origin_addresses" -out=demo.tfplan
```

Use that alternative only when `TF_VAR_origin_addresses` already holds the complete reviewed map; do not combine competing input methods accidentally. Applying a saved plan uses the map captured at plan time, not later file edits.

## Acceptance and troubleshooting reference

The [execution guide](RUNBOOK.md) shows the live message demonstration. Require four Ready workers, healthy system workloads, available app/Redis Deployments, real public endpoints, valid HTTPS, all four exact-provider routes, Local datastore isolation and Shared datastore cross-provider writes/reads. `/api/deployment` reports `mode=local`, `storage=redis` or `mode=shared`, `storage=d1`. HTTP 200, a fallback provider or an available Pod alone is not sufficient. Preserve demo-message IDs and writer metadata for comparison. App replacement must retain Redis/D1 messages; Redis replacement itself has no durability guarantee.

- **AWS worker bootstrap:** keep `vpc-cni.before_compute = true`. Missing CNI caused a failed initial node group; inspect node-group/addon health, IAM, capacity and events. Do not add manual bootstrap infrastructure.
- **Azure 401 / `RequestDisallowedByAzure`:** the observed case required fresh MFA, completed subscription selection and explicit `k8s-talk` selection. Do not bypass MFA. Keep declared `Manual`/`None` node provisioning and `max_surge = "10%"` to prevent service-default drift.
- **GCP 403:** restore the explicit unexpired personal token and personal CLI settings above; never grant work credentials permissions or switch to work ADC.
- **API timeout:** inspect endpoint/network connectivity, cluster health and credentials. All four demo APIs default to all IPv4; review private Terraform overrides if a restriction remains. A successful cloud CLI request or kubeconfig download does not prove Kubernetes reachability/authorization.
- **Pending Pods:** inspect scheduling events and requests. GKE has 940m allocatable CPU; retain one app replica in the single Deployment. The historical baseline requested 828m before the 25m Redis; EKS had 17 Pod slots while the retired example coexisted. The base uses zero surge and one unavailable replica: GKE may briefly lose app availability; three-replica providers retain two replicas but may serve mixed modes until rollout completion. Wait for completion before demonstrating. Do not resize or add workers.
- **Pending Service:** inspect its events and cloud-controller permissions/capacity. Wait for real public endpoints; port-forwarding does not satisfy public-routing acceptance.
- **DigitalOcean 422:** catalog/live capacity is not an authentication problem. The older Intel size no longer listed Sydney; the current `s-2vcpu-4gb` succeeded historically. Do not move continents or delete unrelated Droplets to bypass quota.
- **Worker raw-IP 1003:** use Terraform-managed DNS-only aliases. Direct-origin curl is not proof of Worker compatibility. Inspect `terraform -chdir=infra/cloudflare output origin_hostnames` if needed.
- **Worker 1010:** the zone rejected Python's default User-Agent historically; the explicit `clouds-lab-rehearsal/1.0` User-Agent, Go backends and browsers worked without weakening zone security.
- **TLS/DNS convergence:** inspect custom-domain/certificate status and public DNS. A local resolver briefly missed new ELB names during rehearsal. Do not disable certificate validation or fabricate endpoints.
- **Wrong provider:** a valid `clouds_origin` cookie wins over visitor geography. Require exact `X-Lab-Origin` and `/api/deployment` provider/storage; fallback success is not the selected route. Clear the cookie to test trusted visitor continent: Americas → AWS, Europe/Africa → Azure, Asia → GCP, Oceania → DigitalOcean; unknown geography is random. GET/HEAD alone may fail over; POST is sent once. Local read failover can expose another cluster's dataset.
- **D1 authorization:** the app token must match the Worker secret; management/OAuth tokens are different. Browser calls stay on the application's `/api/messages`; app servers authenticate to `/state/messages`. `/state/*` is handled before origin routing, avoiding recursion.
- **D1 refresh-only changes:** provider 5.28 has planned computed `file_size`, `num_tables`, `version` refreshes. In historical evidence these did not change database UUID/data or price. Inspect the actual plan; do not suppress differences with ignore-all rules.

Messages are bounded to the latest 50 and text to 500 Unicode codepoints. Identical submission ID/payload retries return the original message; conflicting reuse is rejected. SQL values are bound, errors are explicit, and there is no fake/local-memory success fallback. D1 primary-session reads support cross-provider read-after-write. Free-plan [D1](https://developers.cloudflare.com/d1/platform/pricing/) and [Workers](https://developers.cloudflare.com/workers/platform/pricing/) limits still apply.

## Cleanup

**Stop: obtain explicit approval before any deletion.** The current lab remains running under the old app names and billable. Repository changes are not deletion approval. A local/shared switch is not cleanup. The retired original example was already removed in the historical cutover; do not repeat broad cleanup. Full teardown deletes ephemeral Redis messages and **irreversibly deletes D1 shared messages**. Retain the shared Docker Hub repository/image and its independent state, existing Cloudflare zone/domain, GCP project/billing, Azure subscription, accounts and unrelated resources.

Restore all credential/input exports above, especially the original app token, intended API access inputs, personal GCP token and current DO HA `true`. Keep `k8s/shared/credentials.env` through shared deletion rendering. If an earlier stage failed, inspect the original state and live resources; execute only relevant approved steps, not a blind full-success script.

### Remove routing and D1 only after approval

Stop demo use and confirm data deletion is approved before planning destruction of the Cloudflare root. This removes the Worker, routing aliases, custom domain and D1, not merely a frontend switch.

```bash
terraform -chdir=infra/cloudflare plan -destroy -out=destroy.tfplan
terraform -chdir=infra/cloudflare show destroy.tfplan
```

After reviewing the irreversible database deletion and only the intended lab resources:

```bash
terraform -chdir=infra/cloudflare apply destroy.tfplan
```

Inspect DNS and certificate inventory. [Deleting a custom domain does not automatically remove its generated certificate](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/#certificates); remove only the approved lab certificate if one remains. Never delete the zone or unrelated certificates.

### Release apps while cloud controllers still run

Delete the stable app resources once per cluster, plus local Redis, while cloud controllers still run and **before** cluster networking/controllers disappear. Do not blindly delete both overlapping overlays: they own the same `guestbook` Deployment and Service. Then remove scoped generated configuration as described below. Legacy app names require separately approved explicit cleanup. These commands are for approved final teardown, not mode switching.


#### AWS EKS

```bash
kubectl --context eks delete deployment,service guestbook guestbook-local-redis --ignore-not-found --wait=true --timeout=10m
```

#### Azure AKS

```bash
kubectl --context aks delete deployment,service guestbook guestbook-local-redis --ignore-not-found --wait=true --timeout=10m
```

#### Google Cloud GKE

```bash
kubectl --context gke delete deployment,service guestbook guestbook-local-redis --ignore-not-found --wait=true --timeout=10m
```

#### DigitalOcean DOKS

```bash
kubectl --context doks delete deployment,service guestbook guestbook-local-redis --ignore-not-found --wait=true --timeout=10m
```

### Legacy names from the running installation

**Separate explicit deletion approval required.** These commands target running `guestbook-local` / `guestbook-shared` app Deployments/Services and any older `guestbook-stateless` / `guestbook-stateful` installations; the new overlays cannot delete them. Stop traffic to these origins before deletion. For an approved migration, perform only approved legacy removal while retaining required Redis/Worker/D1 resources; full teardown also uses stable resource deletion above. Fresh clusters have no legacy cleanup gate. The canonical `guestbook` name is NOT a legacy cleanup target: old evidence of deleting an original upstream `guestbook` applies only to that historical rehearsal. Do not execute cleanup for repository review.

#### AWS EKS

```bash
kubectl --context eks get deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found
kubectl --context eks delete deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found --wait=true --timeout=10m
```

#### Azure AKS

```bash
kubectl --context aks get deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found
kubectl --context aks delete deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found --wait=true --timeout=10m
```

#### Google Cloud GKE

```bash
kubectl --context gke get deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found
kubectl --context gke delete deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found --wait=true --timeout=10m
```

#### DigitalOcean DOKS

```bash
kubectl --context doks get deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found
kubectl --context doks delete deployment,service guestbook-local guestbook-shared guestbook-stateless guestbook-stateful --ignore-not-found --wait=true --timeout=10m
```

Record former Service endpoints and verify provider-side release of corresponding AWS ELBs, Azure frontend IPs, GCP forwarding rules/load balancers and DigitalOcean load balancers. Kubernetes disappearance alone is not release. Preserve the AKS outbound frontend and unrelated resources. Do not deploy parallel replacement load balancers or destroy clusters until approved old frontends are released. During an approved migration, collect the new stable `guestbook` Service endpoints and update Cloudflare once; never assume addresses carry over.

### Remove generated configuration after apps

Plain apply does not prune old generated hashes. After the corresponding apps are deleted, remove only generated ConfigMaps/Secrets using both scoped labels for that example:


#### AWS EKS

```bash
kubectl --context eks -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=local --ignore-not-found
kubectl --context eks -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=shared --ignore-not-found
```

#### Azure AKS

```bash
kubectl --context aks -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=local --ignore-not-found
kubectl --context aks -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=shared --ignore-not-found
```

#### Google Cloud GKE

```bash
kubectl --context gke -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=local --ignore-not-found
kubectl --context gke -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=shared --ignore-not-found
```

#### DigitalOcean DOKS

```bash
kubectl --context doks -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=local --ignore-not-found
kubectl --context doks -n default delete configmap,secret -l app.kubernetes.io/part-of=cloud-guestbook,app.kubernetes.io/component=shared --ignore-not-found
```

Inspect remaining Services/PVCs, then the provider inventories, before cluster destruction:


#### AWS EKS

```bash
kubectl --context eks -n default get services,persistentvolumeclaims
```

#### Azure AKS

```bash
kubectl --context aks -n default get services,persistentvolumeclaims
```

#### Google Cloud GKE

```bash
kubectl --context gke -n default get services,persistentvolumeclaims
```

#### DigitalOcean DOKS

```bash
kubectl --context doks -n default get services,persistentvolumeclaims
```

A vanished Service does not prove its cloud load balancer is released. Confirm load balancers/frontend IPs for **both legacy and new app names**, plus any later-created volumes, are released in each provider before any Terraform cluster destroy. Preserve the Kubernetes API's own `kubernetes` Service and unrelated resources. Use provider-scoped inventory and exact former cluster IDs/tags, never account-wide deletion.

### Destroy infrastructure with reviewed plans

Refresh the personal GCP access token with the preparation command and inspect/refresh current CIDR inputs. Preserve DO HA `true` while planning the existing cluster. Review each independent destroy plan:

```bash
terraform -chdir=infra/aws plan -destroy -out=destroy.tfplan
terraform -chdir=infra/aws show destroy.tfplan
terraform -chdir=infra/azure plan -destroy -out=destroy.tfplan
terraform -chdir=infra/azure show destroy.tfplan
terraform -chdir=infra/gcp plan -destroy -out=destroy.tfplan
terraform -chdir=infra/gcp show destroy.tfplan
terraform -chdir=infra/digitalocean plan -destroy -out=destroy.tfplan
terraform -chdir=infra/digitalocean show destroy.tfplan
```

Only after approval of every proposed deletion, apply the exact reviewed plans. Independent roots may be operated in separate prepared terminals; no background orchestration is needed.

```bash
terraform -chdir=infra/aws apply destroy.tfplan
terraform -chdir=infra/azure apply destroy.tfplan
terraform -chdir=infra/gcp apply destroy.tfplan
terraform -chdir=infra/digitalocean apply destroy.tfplan
```

Require empty Terraform states and independently verify provider-side absence of clusters, workers, disks, load balancers, public IPs, lab networks and Azure lab/node resource groups:

```bash
terraform -chdir=infra/aws state list
terraform -chdir=infra/azure state list
terraform -chdir=infra/gcp state list
terraform -chdir=infra/digitalocean state list
terraform -chdir=infra/cloudflare state list
```

DigitalOcean previously accepted cluster deletion but left its worker active. Verify Droplets separately; if a worker remains, confirm its exact former cluster-ID tag/name and obtain scoped deletion approval rather than deleting unrelated workers. AWS KMS keys enter `PendingDeletion` for a [mandatory waiting period](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html); record the scheduled date instead of claiming immediate physical deletion. Retain original state/backups, evidence and private credential inputs until verified cleanup is complete; remove private temporary plans/logs only when no longer needed. Retain registry state beyond per-session cleanup.

## Two-example cutover — 2026-10-21

This is historical evidence from before the `local` / `shared` naming and common-base refactor, not verification of `demo-v2`, a new operation or a promised duration. The existing four clusters ran only the two branded Global Guestbook examples. All eight app Deployments were verified Ready on the same immutable multi-architecture image declared in the shared component. Existing branded public endpoints were retained. The original upstream frontend and leader/follower Redis Deployments/Services were deleted; provider APIs confirmed retired original frontends released while both branded endpoints remained.

Passed in that cutover:

- Real Redis container integration tests with `go test -race`, including atomic idempotency, conflicting IDs, concurrent retries and latest-50 behavior; all eight overlays rendered privately.
- Four independent cloud Redis datasets: each provider's own message was present and the other providers' messages absent, directly and through exact-provider Cloudflare HTTPS routes. All three AWS app replicas read the same AWS-local Redis message.
- D1 writes through every provider readable through every other provider, with matching IDs/content/writer metadata. Local Redis messages did not automatically appear in D1.
- Real HTTPS browser proof: an AWS local write was absent through Azure; a GCP shared write appeared through Azure. Both modes served identical HTML/CSS/JS except metadata/storage copy; desktop cards remained equal-height, the message list scrolled and the 390px local preview had no horizontal overflow.
- Redis and D1 messages survived a subsequent app-image rollout across all four providers. Two historical four-provider helper invocations each completed in 52.5 seconds concurrently, reusing Redis, D1 and load balancers; those observations are not execution instructions or timing promises.

The observed existing-cluster cutover took **22.32 minutes**, from first local app apply through final image/data-retention checks, including the initial EKS Pod-slot stall/correction, both routing phases, old-example retirement and image publication. It excluded fresh cluster provisioning and earlier development/image preparation; it is not a fresh-provisioning benchmark.

Scheduling limits were corrected without worker-size increases: GKE had 940m allocatable CPU and 828m already requested before the 25m Redis; EKS had 17 Pod slots while the retired example coexisted. The then-separate app bases used zero surge and one unavailable replica, now retained in `k8s/base`. GKE's single replica has a brief rollout gap; other providers retain two replicas. No replacement load balancers, additional workers or paid-plan upgrades were created.

The subsequent provider-neutral registry cutover published the same OCI index to public Docker Hub, verified anonymous `amd64`/`arm64` manifest access and anonymous image pull, then rolled all eight Deployments onto `docker.io/raelga/clouds-guestbook` without pull credentials. Local/shared messages, all four exact HTTPS routes and both message APIs passed again. The repository was imported into `infra/dockerhub` and a description-only plan applied. After explicit approval, 21 obsolete ECR image digests and the old repository were deleted; AWS Terraform planned only that repository deletion and the provider confirmed absence. No clusters or paid plans changed.

The hostname was left on shared D1 storage, now labeled **Shared datastore**. Independent Local datastore Services remain available for the first demonstration phase. Clusters remain running and billable; full teardown requires separate approval.

## Live rehearsal — 2026-10-21

This historical rehearsal used **three earlier examples**, not the current two-example sequence. Fresh resources started at **08:21:10 UTC**; preflight began at **07:59:51 UTC**. An operator pause interrupted EKS/GKE/DOKS. Existing state and accepted cloud operations were reconciled, not discarded. EKS was preserved without replacement. GKE's interrupted temporary default pool was removed through a separate single-resource Terraform recovery state before the intended worker was created.

| Acceptance milestone | Minutes after first apply | Minutes including preflight |
|---|---:|---:|
| API/application/global-routing checks, 08:56:52 UTC | 35.70 | 57.03 |
| Real-browser acceptance, 08:58:53 UTC | 37.72 | 59.04 |

Reported wall-clock observations were 35m42s to API acceptance, 37m43s to browser acceptance, or 59m03s including preflight/authentication recovery. Rounded table values describe the same run. They are not targets, SLAs or uninterrupted EKS benchmarks; fresh provisioning plus the current two-example demonstration has not been timed again.

Passed in that earlier rehearsal:

- Four Ready workers across North America, Europe, Asia and Oceania, with CNI/DNS/system workloads checked.
- All 12 earlier application targets public/available; original Guestbook Redis writes/reads, stateless fresh UUIDs and correct origin metadata.
- Valid HTTPS and all four exact `X-Lab-Origin` selections for each of the three earlier examples, not fallback acceptance.
- Cross-provider D1 writes/reads, idempotent same-origin retries and retention after replacing the only GCP stateful Pod. Public load-balancer convergence was awaited and the exact replacement process verified.
- Healthy-provider affinity, real browser writes/reads, all four branded headings, a stateless request and a 390px mobile viewport without overflow.

Corrections included Sydney worker catalog selection, Redis leader/follower DNS, GCP replica capacity, IP-origin DNS aliases, explicit future non-HA default and a digest-pinned multi-architecture image. Python's default User-Agent was blocked by zone policy; explicit lab User-Agent requests worked without weakened security. A local resolver briefly missed new AWS ELB names while public DNS and real Cloudflare routing succeeded. Cloudflare provider 5.28 computed D1 statistics changed without database identity/data or pricing-tier changes.

The running DO cluster retained its approved **$40/month HA control plane**, prorated hourly; future fresh configurations request non-HA explicitly. The former ECR repository was later retired only after verified Docker Hub cutover and explicit deletion approval.

Private evidence includes `timings.json`, provider runtime/API logs, `global-checks.json`, `browser-checks.json`, saved plans and independent kubeconfigs in the private run directory. None belong in Git. Keep original state and matching application Secret input. Historical evidence does not waive new acceptance checks or cleanup approval.

### Historical cluster-only measurements

Earlier observations: EKS 6m27s recovery after an initial CNI failure; AKS 4m40s creation; GKE about 12m creation; DOKS 9m33s on a previously available Intel size. Those excluded applications and HTTPS and are not capacity or timing guarantees. In the later interrupted fresh rehearsal, EKS worker Ready was 08:36:16 UTC (15m06s after initial apply), AKS creation was 4m05s / worker Ready 08:25:28 UTC, GKE worker Ready was 08:40:22 UTC and the accepted DOKS creation completed after 11m03s. Do not substitute recovery or historical cluster-only observations for a new end-to-end run.
