# Kubernetes Clouds

Compare managed Kubernetes across AWS EKS, Azure AKS, Google Cloud GKE, and DigitalOcean Kubernetes.

The lab provides **two storage modes with the same Global Guestbook message UI**: **Local datastore** (`local`) in cluster-local Redis and **Shared datastore** (`shared`) in Cloudflare D1. Both keep messages outside application Pods. Both variants use one stable `guestbook` Deployment and LoadBalancer Service per cluster, with `app=guestbook` selectors. Applying the other variant rolls that Deployment without changing its Service address; configure Cloudflare once. Switching storage does not migrate messages. This repository-only change does not alter running `guestbook-local` / `guestbook-shared` resources or older `guestbook-stateless` / `guestbook-stateful` installations. Migrating those requires separate approval, legacy cleanup, collection of the new Service addresses and a one-time Cloudflare update; no live changes are authorized here.

Application resources are deployed as declarative YAML through Kustomize provider overlays. `k8s/base` defines the common Deployment, Service and image pin; `k8s/local` adds Redis and `k8s/shared` adds Worker/D1 configuration and generated Secrets. Terraform manages cloud infrastructure.

## Directory map

```text
infra/              # provider Terraform roots and infrastructure guides
app/guestbook/      # Go application and Docker build context
app/router/         # Cloudflare Worker and local Wrangler workspace
k8s/                # declarative application manifests and provider overlays
RUNBOOK.md          # human execution guide
RUNBOOK-DETAILED.md # setup, troubleshooting, cleanup and historical evidence
```

Existing local state, caches and private credential inputs are retained in their new locations and remain ignored; do not commit or discard them.

Historical AWS infrastructure templates, Kubernetes setup manifests and the original Guestbook screenshot live in the repository-root [archive](../archive/). They are not used to provision or deploy the current lab.

## Workshop slides

The [slide source](kubernetes-clouds.slide) is an architecture overview: goals, proposed approach, a global four-cloud topology, Cloudflare Workers and shared application data. Deployment commands and operational details stay in the runbooks.

Preview locally with Go and the pinned presentation tool. This renderer requires Go 1.26 or automatic toolchain downloading:

```bash
go run golang.org/x/tools/cmd/present@v0.52.0 -http=127.0.0.1:3999 -play=false
```

Open [the local slide deck](http://127.0.0.1:3999/kubernetes-clouds.slide). Stop the server after presenting. The [operator runbook](RUNBOOK.md) contains executable commands; slides are not a replacement for its prerequisites or message demonstrations.

All four demo Kubernetes APIs default to public IPv4 `0.0.0.0/0`; authentication and Kubernetes RBAC remain required. This is deliberate temporary-demo exposure, not a production setting. See [API inputs and private override precedence](RUNBOOK-DETAILED.md#demo-api-access), including clearing stale `TF_VAR_cluster_api_allowed_cidrs`.

## Kubernetes Clouds Labs

Start with the [execution guide](RUNBOOK.md) for readiness, Local datastore isolation and Shared datastore messages. The [detailed reference](RUNBOOK-DETAILED.md#preparation) provides credentials, required inputs, fresh-only setup, troubleshooting, [approved cleanup](RUNBOOK-DETAILED.md#cleanup) and historical evidence. Each provider guide supplies infrastructure-specific detail. Run commands from the repository root.

The main workflow is interactive: `cd` into the provider root, run `terraform init -lockfile=readonly`, inspect `terraform plan`, then review and confirm `terraform apply`. Return to the project root before Kubernetes commands. Exact saved plans are an [optional advanced reference](RUNBOOK-DETAILED.md#optional-advanced-reference-exact-saved-plans). Local kubectl aliases are `eks`, `aks`, `gke` and `doks`; actual cloud resource names remain unchanged.

| Provider guide | Cluster | Region / continent |
|---|---|---|
| [AWS EKS](infra/aws/README.md) | `clouds-eks` | `us-east-1` / North America |
| [Azure AKS](infra/azure/README.md) | `clouds-aks` | `westeurope` / Europe |
| [Google Cloud GKE](infra/gcp/README.md) | `clouds-gke` | `asia-northeast1-a` / Asia |
| [DigitalOcean DOKS](infra/digitalocean/README.md) | `clouds-doks` | `syd1` / Oceania |

Use only the personal `me@rael.io` identity and `bcncloud-gke` project for GCP; do not use work/Red Hat credentials or quotas. Each Terraform root has separate local state, which must be retained until its resources are destroyed. Apply creates billable resources.

The [detailed reference](RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21) records historical two-example cutover evidence, not acceptance of this stable-identity change. The earlier three-example fresh-provisioning rehearsal took an observed 59m03s including recovery, not a target or guarantee; the current workflow has not been timed again. The [application guide](k8s/README.md) specifies Local datastore isolation followed by Shared datastore D1. Resources remain billable until approved cleanup; no paid Cloudflare upgrade is included. The [Cloudflare guide](infra/cloudflare/README.md) documents origin aliases, credentials and routing limitations. Preserve approved DigitalOcean HA and existing load balancers until separately approved migration or cleanup.