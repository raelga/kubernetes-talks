# Azure: Terraform-managed AKS in Europe

Follow [RUNBOOK.md](../../RUNBOOK.md) for execution and the [detailed reference](../../RUNBOOK-DETAILED.md#preparation) for authentication and shared inputs. Run commands from the project root. Terraform is the sole owner of AKS and the lab resource group; Azure CLI authenticates, retrieves kubeconfig and inspects resources, not a parallel creation/deletion workflow.

## Configuration

| Setting | Current configuration |
|---|---|
| Terraform root | `infra/azure` |
| Subscription | Intended personal `k8s-talk` subscription; keep its ID private |
| Region | `westeurope`, Europe |
| Resource group / cluster | `clouds-aks-rg` / `clouds-aks` |
| Kubernetes | `1.36.4` |
| System worker | One `Standard_B2s`, 30 GiB OS disk |
| AKS tier | `Free` |
| Networking | Azure network plugin, Standard load balancer, load-balancer outbound traffic |
| API | Public IPv4 `0.0.0.0/0` by default; optional `cluster_api_allowed_cidrs` override |
| Dependencies | Terraform `>= 1.9, < 2.0`; AzureRM `~> 5.10`, lock `5.10.0` |
| kubectl context | `aks` |

The Free AKS tier does not make workers, disks, IPs, load balancers or networking free. Preserve sizing and obtain approval before billing changes or deletion. Both modes use one stable `guestbook` Deployment/LoadBalancer Service (`app=guestbook`) and the same anonymously pulled digest-pinned Docker Hub image. Configure Cloudflare once; mode rollouts do not change origins. Existing differently named apps are not renamed here: migration requires separate approval, new Service addresses and a one-time origin update. No live deployment is authorized. Local Redis is ephemeral; switching to D1 migrates no messages.

The AzureRM v5 configuration explicitly declares `node_provisioning_profile` as `mode = "Manual"`, `default_node_pools = "None"`, and node-pool `upgrade_settings.max_surge = "10%"`. These match the service and avoid repeated drift; do not replace them with `ignore_changes`.

## Authentication and prerequisites

Install [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli), [Terraform](https://developer.hashicorp.com/terraform/install), compatible kubectl and curl. Check `westeurope` Kubernetes/SKU availability, regional and VM-family vCPU quotas, subscription policy and resource-provider registration before applying. Required providers include `Microsoft.ContainerService`, `Microsoft.Compute`, `Microsoft.Network` and `Microsoft.ManagedIdentity`; the Terraform identity needs permission to manage/register intended resources. See [AKS quotas](https://learn.microsoft.com/en-us/azure/aks/quotas-skus-regions) and [resource providers](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-providers-and-types).

Complete interactive MFA with the fresh device code and URL. Wait for `az login` and its subscription-selection prompt to finish:

```bash
az login --use-device-code
```

Select and confirm the exact enabled subscription:

```bash
az account set --subscription k8s-talk
az account show --query '{name:name,id:id,state:state}' --output table
```

Terraform also defaults to this subscription ID; choosing another CLI subscription does not override the Terraform input. Never print/commit credentials.

## Review a plan

The temporary demo API is deliberately public; authentication and Kubernetes RBAC remain required. Run `unset TF_VAR_cluster_api_allowed_cidrs` to clear the old environment override. Private tfvars and command-line inputs can still override the default; see [API access and precedence](../../RUNBOOK-DETAILED.md#demo-api-access). Use the existing local state, not a new replacement state. Preserve lockfiles, state/backups and private plans.

```bash
cd infra/azure
terraform init -lockfile=readonly
terraform plan
```

Review subscription, region, allowlist, worker count and all actions. Only after required approval of intended changes:

```bash
terraform apply
cd ../..
```

Interactive `terraform apply` displays a fresh plan and asks for confirmation. Review it again before typing `yes`. For an optional exact saved-plan workflow, see the [advanced reference](../../RUNBOOK-DETAILED.md#optional-advanced-reference-exact-saved-plans).

## Kubeconfig and readiness

The command updates local kubeconfig and may change its current context; use explicit contexts afterward.

```bash
az aks get-credentials --resource-group clouds-aks-rg --name clouds-aks --subscription k8s-talk --context aks --overwrite-existing
kubectl --context aks cluster-info
kubectl --context aks wait --for=condition=Ready nodes --all --timeout=10m
kubectl --context aks -n kube-system rollout status deployment/coredns --timeout=10m
kubectl --context aks get nodes -o wide
kubectl --context aks -n kube-system get pods
```

Require one Ready node and healthy CoreDNS. Infrastructure readiness does not prove app load-balancer readiness or message contracts; continue in the execution guide.

## Troubleshooting and historical evidence

- Observed `RequestDisallowedByAzure` / HTTP 401 required fresh device-code MFA and completed subscription selection, not an MFA bypass or manual resource creation.
- API timeout requires checking connectivity, cluster health, credentials and any private CIDR override. Kubeconfig retrieval does not change API access settings.
- Quota/SKU/version/policy errors require checking this subscription and region; do not silently resize or change continents.
- After interruption, retain state and make a fresh plan against accepted cloud operations. Do not delete state or manually recreate Terraform-owned resources.

A historical cluster-only apply took about 4m40s excluding MFA. In the 2026-10-21 three-example rehearsal creation took 4m05s, the worker was Ready at 08:25:28 UTC, and all three earlier app targets passed direct/global checks. One Azure load balancer exposed their frontend IPs plus the cluster outbound IP. These are observations, not targets or proof of the later two-example cutover. See [historical rehearsal](../../RUNBOOK-DETAILED.md#live-rehearsal--2026-10-21) and [two-example evidence](../../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21).

## Approved teardown (optional advanced saved-plan reference)

Explicit approval is required. Follow [full cleanup](../../RUNBOOK-DETAILED.md#cleanup): remove routing, delete stable app resources once, remove scoped generated configuration and separately approved legacy names while controllers run. Do not blindly delete both overlapping overlays. Confirm provider-side app frontend-IP/load-balancer/volume release before Terraform destruction, preserving the cluster outbound frontend until AKS teardown. Mode switching retains the single app Service and local Redis. Retain original state and unrelated resources.

With intended API inputs and the same subscription/credentials prepared:

```bash
terraform -chdir=infra/azure plan -destroy -out=destroy.tfplan
terraform -chdir=infra/azure show destroy.tfplan
```

After reviewing and approving every deletion:

```bash
terraform -chdir=infra/azure apply destroy.tfplan
terraform -chdir=infra/azure state list
```

Verify provider-side deletion of the lab and managed node resource groups, workers, disks, IPs and networking; empty state alone is insufficient. Do not delete the resource group with Azure CLI as a substitute for Terraform. Preserve the subscription, shared registry and unrelated resources. Retain state/backups until cleanup is verified. See [other infrastructure guides](../README.md).
