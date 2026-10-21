# Cloud infrastructure

Follow the [execution guide](../RUNBOOK.md) for the four-cloud demonstration. Use the [detailed reference](../RUNBOOK-DETAILED.md#preparation) for credentials, required inputs, fresh-only bootstrap, troubleshooting and [approved cleanup](../RUNBOOK-DETAILED.md#cleanup). There is no clock target: proceed when each readiness and application gate passes.

| Provider guide | Terraform root | Location |
|---|---|---|
| [AWS EKS](aws/README.md) | `infra/aws` | Virginia, North America |
| [Azure AKS](azure/README.md) | `infra/azure` | Netherlands, Europe |
| [Google Cloud GKE](gcp/README.md) | `infra/gcp` | Tokyo, Asia |
| [DigitalOcean DOKS](digitalocean/README.md) | `infra/digitalocean` | Sydney, Oceania |
| [Cloudflare](cloudflare/README.md) | `infra/cloudflare` | Global Worker, D1 and routing |
| [Docker Hub](dockerhub/README.md) | `infra/dockerhub` | Shared public image repository |

Run guide commands from the project root. Terraform owns infrastructure, with separate local state/cache in each root; retain states and backups until verified resource deletion. Do not provision the same resources manually. Provider CLIs are used for authentication, kubeconfig retrieval and read-only inspection. Preserve checked-in lockfiles; do not upgrade dependencies during execution.

The main workflow is interactive: `cd` into the provider root, run `terraform init -lockfile=readonly`, inspect `terraform plan`, then review and confirm `terraform apply`. Return to the project root before Kubernetes commands. Exact saved plans are an [optional advanced reference](../RUNBOOK-DETAILED.md#optional-advanced-reference-exact-saved-plans). Local kubectl aliases are `eks`, `aks`, `gke` and `doks`; actual cloud resource names remain unchanged.

Preserve cluster sizes and existing DigitalOcean approved HA (`TF_VAR_control_plane_ha=true`) until separately approved teardown; fresh non-HA defaults do not authorize changing the running cluster. Both variants now target stable `guestbook` app resources. Running `guestbook-local` / `guestbook-shared` and older stateless/stateful resources are not renamed; migration requires separate approval, new Service addresses and a one-time Cloudflare update. No live mutation is authorized here. GCP uses only personal `me@rael.io` / `bcncloud-gke`, never Red Hat/work identities, ADC, projects, tools or quotas.

All four Kubernetes APIs default to public IPv4 `0.0.0.0/0` for this temporary demo; authentication and Kubernetes RBAC remain required. AWS/Azure/GCP use optional `cluster_api_allowed_cidrs`; DigitalOcean uses independent optional `control_plane_allowed_cidrs`. Clear stale `TF_VAR_cluster_api_allowed_cidrs` and review private input overrides before planning; see [API access and precedence](../RUNBOOK-DETAILED.md#demo-api-access).

Application source is in `app/guestbook`, Worker source/local development in `app/router`, and declarative application YAML/Kustomize in `k8s`. `aws/legacy` preserves historical manual templates, not the current workflow. Both app modes use the same public Docker Hub image, tag `demo-v2` pinned by digest; cluster pulls are anonymous. Keep the shared Docker Hub repository/state beyond per-session cluster teardown.

## Application and global hostname

The [application guide](../k8s/README.md) describes Local datastore (`local`, one ephemeral Redis per cluster), then Shared datastore (`shared`, Worker/D1), with one stable `guestbook` Deployment and LoadBalancer Service per cluster (`app=guestbook`). Both reuse `k8s/base`; provider overlays remain `k8s/overlays/{provider}/{local,shared}`. Configure Cloudflare once, then roll the same Deployment between modes without changing origins. Wait for rollout completion and all desired replicas Ready before demonstrating: modes may briefly coexist behind the Service. Switching does not migrate data. The [Cloudflare guide](cloudflare/README.md) explains credentials and origin inputs.

The [two-example cutover evidence](../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21) and [historical three-example rehearsal](../RUNBOOK-DETAILED.md#live-rehearsal--2026-10-21) do not verify this stable-identity cutover. Durations are not guarantees. Resources remain billable until approved cleanup. Delete stable app resources once, remove scoped generated configuration and separately approved [legacy app names](../RUNBOOK-DETAILED.md#legacy-names-from-the-running-installation), then verify provider-side load-balancer/frontend-IP/volume release while controllers still run before destroying infrastructure. Do not blindly delete both overlapping overlays; empty Terraform state alone is insufficient.
