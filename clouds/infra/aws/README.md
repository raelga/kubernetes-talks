# AWS: Terraform-managed EKS in North America

Use the [execution guide](../../RUNBOOK.md) for the demonstration and the [detailed preparation reference](../../RUNBOOK-DETAILED.md#preparation) for credentials and shared inputs. This guide explains the AWS leg, not a separate provisioning workflow. Run commands from the project root.

## Configuration and ownership

| Setting | Current configuration |
|---|---|
| Terraform root | `infra/aws` |
| Cluster / region | `clouds-eks` / `us-east-1`, North America |
| Kubernetes | `1.36` |
| Worker | One managed `t3.medium`; minimum/desired/maximum all `1` |
| Network | VPC `10.20.0.0/16`; three public `/20` subnets across three available AZs; public node IPs; no NAT gateway |
| API | Private access enabled; public IPv4 `0.0.0.0/0` by default; optional `cluster_api_allowed_cidrs` override |
| Addons | VPC CNI, CoreDNS, kube-proxy; CNI installed before compute |
| Dependencies | Terraform `>= 1.9, < 2.0`; AWS provider `~> 6.0`, lock `6.69.1`; EKS module `21.29.0`, VPC module `6.7.2` |
| kubectl context | `eks` |

Terraform alone owns infrastructure; do not mix manual AWS, CloudFormation, kops or eksctl resources into it. Legacy templates are historical. Preserve this billable single-worker lab's sizing. Both storage modes use one stable `guestbook` Deployment/LoadBalancer Service (`app=guestbook`) and the same anonymously pulled digest-pinned Docker Hub image; this root no longer creates ECR. Configure Cloudflare once, not at mode changes. Existing differently named apps are not renamed here: migration requires separate approval, new Service addresses and a one-time origin update. No live deployment is authorized.

## Authentication and prerequisites

Install [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), [Terraform](https://developer.hashicorp.com/terraform/install), compatible [kubectl](https://kubernetes.io/docs/tasks/tools/) and curl. Select the intended deployment `AWS_PROFILE` if needed and complete its approved login workflow. Confirm account/principal before Terraform:

```bash
aws sts get-caller-identity
```

The deployment identity needs authorization for declared EKS clusters/node groups/addons/access entries, EC2 network/node resources, IAM roles/policies/pass-role, KMS keys/grants and CloudWatch logging. This is a capability summary, not a least-privilege policy. Organization policy, service-linked roles and quotas also apply. Have the administrator review the plan/module requirements rather than treating a successful identity check as create permission.

Check regional EKS 1.36, addon/AMI compatibility, `t3.medium` capacity and quotas using current [EKS documentation](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html). AMI/addon choices can be resolved dynamically; the lockfile does not freeze cloud-side catalogs. Preserve the lockfile; no `init -upgrade` during execution.

## Review a plan

The temporary demo API is deliberately public; authentication and Kubernetes RBAC remain required. Run `unset TF_VAR_cluster_api_allowed_cidrs` to clear the old environment override. Private tfvars and command-line inputs can still override the default; see [API access and precedence](../../RUNBOOK-DETAILED.md#demo-api-access). Keep the original local state and backups. Plans/state can contain secrets; never commit them or create a second empty state for the same cluster.

```bash
cd infra/aws
terraform init -lockfile=readonly
terraform plan
```

Review account, region, API CIDRs, worker count, billable resources and every replacement/deletion. Apply only intended reviewed changes, after required approval:

```bash
terraform apply
cd ../..
```

Interactive `terraform apply` displays a fresh plan and asks for confirmation. Review it again before typing `yes`. For an optional exact saved-plan workflow, see the [advanced reference](../../RUNBOOK-DETAILED.md#optional-advanced-reference-exact-saved-plans).

## Kubeconfig and readiness

AWS CLI's native EKS token command supplies authentication; no separate Heptio authenticator is required. Credentials must remain valid for later kubectl calls.

```bash
aws eks update-kubeconfig --region us-east-1 --name clouds-eks --alias eks
kubectl --context eks wait --for=condition=Ready nodes --all --timeout=10m
kubectl --context eks -n kube-system rollout status deployment/coredns --timeout=10m
kubectl --context eks -n kube-system rollout status daemonset/aws-node --timeout=10m
kubectl --context eks -n kube-system rollout status daemonset/kube-proxy --timeout=10m
kubectl --context eks get nodes -o wide
kubectl --context eks -n kube-system get pods
```

Expect one Ready worker and healthy system workloads. Terraform completion alone does not prove app/public-load-balancer readiness. Continue with the execution guide's direct Kustomize app commands, not a second provisioning owner.

## Recovery and historical evidence

Keep `vpc-cni.before_compute = true`: the initial worker failed after about 33 minutes without CNI-before-compute ordering. Historical recovery took 6m27s, **not clean creation**. In the later interrupted rehearsal the worker was Ready at 08:36:16 UTC, 15m06s after initial apply, including pause/recovery. These are observations, not guarantees. See [dated evidence](../../RUNBOOK-DETAILED.md#live-rehearsal--2026-10-21) and the separate [two-example cutover](../../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21).

For failed workers/addons, inspect node-group/addon health, Kubernetes events, IAM, CNI ordering, quota and capacity before a fresh plan against original state. Do not replay stale creation plans after interruption. For API timeouts, inspect connectivity and any private CIDR override. Authentication failure requires checking the actual CLI identity/session and EKS access. A reachable API alone does not grant Kubernetes permissions. Newly created ELB names historically lagged the local resolver while public DNS/Cloudflare succeeded; never invent endpoint values or disable TLS validation.

## Approved teardown (optional advanced saved-plan reference)

Full teardown requires explicit approval; mode switching is not teardown. Follow [controller-first cleanup](../../RUNBOOK-DETAILED.md#cleanup): remove routing, delete stable app resources once, remove scoped generated configuration and separately approved legacy app names. Do not blindly delete both overlapping overlays. Confirm provider-side app ELB/volume release while controllers run before Terraform destruction. Preserve shared Docker Hub state and unrelated resources. The former ECR repository was removed after approved registry cutover; do not recreate it.

With original credentials/state and intended API inputs reviewed, review the destructive plan:

```bash
terraform -chdir=infra/aws plan -destroy -out=destroy.tfplan
terraform -chdir=infra/aws show destroy.tfplan
```

After explicit approval of its deletions:

```bash
terraform -chdir=infra/aws apply destroy.tfplan
terraform -chdir=infra/aws state list
```

Verify provider-side absence as well as empty state. KMS deletion has a mandatory waiting period; record `PendingDeletion` and the scheduled date, not immediate physical deletion. Retain state/backups/evidence until cleanup is verified. See the [infrastructure index](../README.md) for the other providers.
