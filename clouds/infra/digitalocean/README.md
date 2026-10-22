# DigitalOcean: Terraform-managed DOKS in North America

Follow [RUNBOOK.md](../../RUNBOOK.md) for execution and [detailed preparation](../../RUNBOOK-DETAILED.md#preparation) for credentials/inputs. Run commands from the project root. Terraform owns the cluster and worker pool; doctl authenticates, retrieves kubeconfig and inspects resources, not a second creation/deletion workflow.

## Configuration and non-HA default

| Setting | Configured value |
|---|---|
| Terraform root | `infra/digitalocean` |
| Region | `nyc1`, New York, North America |
| Cluster | `clouds-doks` |
| Kubernetes | `1.36.5-do.1` |
| Worker | One `s-4vcpu-8gb`, 4 vCPU / 8 GiB; catalog $48/month |
| API | Enabled control-plane firewall allowing `0.0.0.0/0`; Kubernetes authentication still required |
| kubectl context | `doks` |
| Control plane | Explicit non-HA `control_plane_ha=false` |

All demo infrastructure is currently destroyed; preserve historical state/backups and private inputs. For a future approved fresh run, clear stale historical HA overrides and use:

```bash
export TF_VAR_control_plane_ha=false
```

Kubernetes 1.36+ [defaults omitted HA requests to billable HA](https://docs.digitalocean.com/products/kubernetes/how-to/create-clusters/#create-a-cluster-using-automation); Terraform sends explicit `false`. The former Sydney cluster used an approved $40/month HA control plane and a $24/month smaller worker; those are historical costs, not this new configuration. [DigitalOcean cannot disable HA on an existing cluster](https://docs.digitalocean.com/products/kubernetes/how-to/enable-high-availability/), even if Terraform shows an in-place update. Check [current pricing](https://docs.digitalocean.com/products/kubernetes/details/pricing/); ask before tier changes, replacements or billing increases.

Preserve the user-selected `s-4vcpu-8gb` size. Both modes use one stable `guestbook` Deployment/LoadBalancer Service (`app=guestbook`) and the same anonymously pulled digest-pinned public Docker Hub image. Configure Cloudflare once; mode rollouts do not change origins. Fresh clusters require no legacy app migration. No live provisioning or billing change is authorized. Local datastore uses ephemeral per-cluster Redis; Shared datastore uses D1 without data migration. This single-worker demo is not production HA.

## Credentials and preflight

Install Terraform `>= 1.9, < 2.0`, compatible kubectl and [doctl](https://docs.digitalocean.com/reference/doctl/how-to/install/). Load the existing API token privately into `DIGITALOCEAN_TOKEN` for Terraform and export it as `DIGITALOCEAN_ACCESS_TOKEN` for doctl using the detailed preparation steps. Never print/commit tokens, state, plans or kubeconfig.

Inspect account quota and New York catalog support:

```bash
doctl account get
doctl kubernetes options regions
doctl kubernetes options versions
doctl kubernetes options sizes
doctl compute size list
doctl kubernetes cluster list
```

Read-only catalog inspection confirmed `nyc1` supports `s-4vcpu-8gb`; this does not guarantee live capacity. The historically inspected account had a three-Droplet limit; recheck quotas because surge upgrades may need spare capacity. Do not delete unrelated resources to make room. Keep the pinned region/version/size and preserve lockfiles; no `init -upgrade` during execution.

## Review a plan

DigitalOcean uses independent optional `control_plane_allowed_cidrs`, defaulting to `["0.0.0.0/0"]` for this temporary demo, like the other three APIs. It does not consume `TF_VAR_cluster_api_allowed_cidrs`. This deliberate internet exposure still requires authentication and Kubernetes RBAC. Private tfvars or command-line inputs can override the default; see [input precedence](../../RUNBOOK-DETAILED.md#demo-api-access). Use original state and review effective non-HA `false`; plans/state can contain secrets.

Historical live verification of the former Sydney cluster's firewall change applied only an in-place update. Authenticated `kubectl` reported the worker Ready; unauthenticated node listing was rejected with HTTP 403. Its then-existing cluster ID, HA tier and worker configuration were preserved. This does not verify the unprovisioned New York topology.

```bash
cd infra/digitalocean
terraform init -lockfile=readonly
terraform plan
```

Review `nyc1`, one `s-4vcpu-8gb` worker, non-HA `false`, firewall CIDRs and every action. Only apply intended changes after required approval:

```bash
terraform apply
cd ../..
```

Interactive `terraform apply` displays a fresh plan and asks for confirmation. Review it again before typing `yes`. For an optional exact saved-plan workflow, see the [advanced reference](../../RUNBOOK-DETAILED.md#optional-advanced-reference-exact-saved-plans).

## Kubeconfig and readiness

Read the cluster UUID from Terraform instead of hardcoding a rehearsal ID. The substitution captures an output, not a new resource.

```bash
export DOKS_CLUSTER_ID="$(terraform -chdir=infra/digitalocean output -raw cluster_id)"
doctl kubernetes cluster kubeconfig save "$DOKS_CLUSTER_ID" --alias doks
kubectl --context doks wait --for=condition=Ready nodes --all --timeout=5m
kubectl --context doks get nodes -o wide
kubectl --context doks -n kube-system rollout status deployment/konnectivity-agent --timeout=5m
kubectl --context doks -n kube-system get pods
```

Require a Ready worker and healthy system workloads; a visible control plane is not acceptance. Follow the execution guide for app/public-load-balancer and message proof.

## Troubleshooting and historical evidence

In the historical Sydney run, the old `s-2vcpu-4gb-120gb-intel` size was unavailable and `s-2vcpu-4gb` succeeded. Neither is the new user-selected `s-4vcpu-8gb` configuration. A 422 capacity error is not fixed by changing credentials. Do not silently move continents or resize. The demo deliberately permits all IPv4 addresses to its API; for a restricted deployment, use `control_plane_allowed_cidrs`. Fresh clusters explicitly default to non-HA.

In the historical 2026-10-21 rehearsal, accepted creation completed after 11m03s. Terraform was gracefully interrupted and later reported `execution halted`, but original state tracked the untainted cluster; the API reported running, the worker became Ready, and a fresh plan proposed only missing outputs. Replaying the original creation plan was not necessary. Retain state and reconcile after interruption.

Earlier three-example direct/global routing, Redis and D1 checks passed. Those are historical observations, not duration/capacity guarantees or proof of the current cutover. See [historical rehearsal](../../RUNBOOK-DETAILED.md#live-rehearsal--2026-10-21) and [two-example evidence](../../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21).

## Approved teardown (optional advanced saved-plan reference)

Obtain explicit approval, then follow [full cleanup](../../RUNBOOK-DETAILED.md#cleanup). Remove routing, delete stable app resources once, remove scoped generated configuration and separately approved legacy names while controllers run; do not blindly delete both overlapping overlays. Verify provider-side load-balancer/volume release before Terraform destruction. Mode switching retains the single app Service and local Redis; it is not teardown.

For future approved teardown, use original state/credentials and match inputs to the actual cluster configuration (fresh HA default `false`), not historical HA overrides:

```bash
terraform -chdir=infra/digitalocean plan -destroy -out=destroy.tfplan
terraform -chdir=infra/digitalocean show destroy.tfplan
```

After approving the destructive plan:

```bash
terraform -chdir=infra/digitalocean apply destroy.tfplan
terraform -chdir=infra/digitalocean state list
```

Check provider-side cluster, worker Droplet, load-balancer and volume absence separately. A previous deletion left an active worker despite accepted cluster deletion: confirm exact former cluster-ID tag/name before any separately approved orphan deletion. Billing continues while resources remain. Retain state/backups/private inputs until verified cleanup; preserve shared registry and unrelated resources. See the [infrastructure index](../README.md).
