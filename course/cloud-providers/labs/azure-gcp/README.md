# Azure and GCP: offline comparison and optional live walkthrough

Compare a dedicated network, a small VM serving Python HTTP JSON on port 8080, and empty **private** object storage. The VM does not access storage. No Docker, Kubernetes, cloud keys or IAM changes are involved. Terraform shares a language and workflow across providers, not APIs or state.

Start offline: **no cloud accounts, credentials, Terraform or cloud CLIs are required**. The optional [live walkthrough](instructor-guide.md) creates billable resources and requires your own approved scope, credentials and existing backends. Synthetic fixtures are not evidence of a real deployment; these instructions do not certify cloud availability or validation.

## 1. Run the offline comparison

Use Python **3.11+**, with no external Python packages. From the repository root:

```sh
cd course/cloud-providers/labs/azure-gcp
export LAB_ROOT="$(pwd -P)"
python3 --version
python3 "$LAB_ROOT/scripts/normalize.py" fixture --provider azure
python3 "$LAB_ROOT/scripts/normalize.py" fixture --provider gcp --running-only
python3 "$LAB_ROOT/scripts/normalize.py" fixture --provider aws --running-only
```

Read [the fixtures](fixtures/) and [the adapter](scripts/normalize.py). Each fixture has `{source, provider, description, data}`: `source=synthetic` identifies invented data; `data` is a subset of a CLI response, not a real capture. Azure models `az vm list --show-details`, GCP models `gcloud compute instances list --format=json`, and AWS models `aws ec2 describe-instances` for comparison only. Fixture mode never calls APIs. Provenance goes to stderr; normalized JSON goes to stdout.

To inspect the same [application](app.py) used by both VM templates:

```sh
HTTP_HOST=127.0.0.1 python3 "$LAB_ROOT/app.py"
# In another terminal:
curl --fail --show-error http://127.0.0.1:8080/health
```

Stop with Ctrl-C. Keep the local listener on loopback, not an externally accessible interface.

## 2. Compare provider concepts

| Intent | AWS | Azure | GCP |
|---|---|---|---|
| Identity and scope | Account, principal, IAM | Entra tenant, subscription, resource group, RBAC | Organization/folder/project, principal, IAM |
| Network | Regional VPC, zonal subnet, instance security group | Regional VNet, subnet, NIC-associated NSG | Global VPC, regional subnet, network-tag-targeted firewall |
| VM | EC2, AMI, type, availability zone | Linux VM, image, SKU, region | Compute Engine, image, machine type, zone |
| Private objects | S3 with public access blocking | LRS Storage Account, private container, no shared keys | Cloud Storage, uniform access, public access prevention |
| Registry, not deployed | ECR | ACR | Artifact Registry |
| Managed services, not deployed | RDS / EKS | Azure Database / AKS | Cloud SQL / GKE |
| Management boundary | Tagged resources | Dedicated resource group and tags | Explicit project and labels; project is not created or deleted |

Read the [Azure variables](azure/terraform/variables.tf), [GCP variables](gcp/terraform/variables.tf) and their `main.tf`/`outputs.tf` companions. These are independent root modules with separate state. Azure needs a public SSH key even though SSH is blocked; GCP requires an explicit project, region and matching zone. `templatefile` embeds the application; it is not a child module, and shared Terraform syntax does not make NSGs and GCP firewalls interchangeable.

## 3. Understand normalized results

The adapter returns only `provider`, `name`, `location`, `state`, sorted deterministically. Provenance stays outside those fields. States are `running`, `stopped`, `pending`, `stopping`, `suspended`, `terminated` or `unknown`; `--running-only` filters the common schema, not provider-specific fields.

- **Azure provisioning is not power state.** `provisioningState=Succeeded` alone yields `unknown`. Running/stopped status comes from `powerState` or `PowerState/...` in `instanceView.statuses`.
- **GCP `TERMINATED` means stopped**, not deleted. `RUNNING` maps to `running`.
- `location` preserves the provider's region or zone: Azure `location`, the final component of GCP `zone`, and AWS `AvailabilityZone`. It does not invent regional equivalence.
- Unknown state values must not become `running`. Valid empty inventory produces `[]`; invalid JSON, malformed required fields or mismatched source/provider exit nonzero, not an empty success.

### Expected results

| Provider | Name | Location | State | Passes `--running-only` |
|---|---|---|---|---|
| aws | aws-demo-running | eu-west-1a | running | yes |
| aws | aws-demo-stopped | eu-west-1b | stopped | no |
| azure | azure-demo-running | westeurope | running | yes |
| azure | azure-demo-stopped | westeurope | stopped | no |
| azure | azure-demo-unknown | westeurope | unknown | no |
| gcp | gcp-demo-running | europe-west1-b | running | yes |
| gcp | gcp-demo-stopped | europe-west1-b | stopped | no |

Optional: implement your own adapter outside the repository and compare these semantics. If using an AI assistant, share only synthetic fixtures and code, review field mappings against provider schemas, and never share credentials, private captures, Terraform state or account identifiers.

## 4. Optional authorized live walkthrough

Follow the [live guide](instructor-guide.md) for prerequisites, CLI and ADC authentication, existing remote state, configuration, plan/apply, HTTP verification, changes and scoped cleanup. Use one or both providers only where authorized; neither is required for the offline path.

Live safety boundaries:

- HTTP is unencrypted TCP 8080 from an explicit IPv4 /24–/32, preferably your outbound IP /32; never `0.0.0.0/0`. Azure denies other inbound traffic, including SSH. GCP uses a dedicated VPC with no default SSH rules. Check inherited policies too.
- VMs use system Python, systemd and user `nobody`; package installation needs outbound Internet. A running VM is not proof of HTTP readiness: check `/health` separately. Storage remains empty and nonpublic, without VM access.
- Names use `upc-2026-cloud-03-<lab_id>` and ownership tags/labels `course=upc-2026`, `lab=cloud-03`, `lab_id=<lab_id>`. These strings and backend keys are **machine contracts** used by capture/cleanup scripts; do not rename them independently. Some GCP resources have no labels and are matched by exact name/prefix.
- [Existing remote backends](instructor-guide.md#remote-state-and-authentication) use Blob leases or GCS Terraform locking. Never use the application storage as a backend, share state keys, or bypass active locks.

### Capture and normalize

After live setup, the guide provides the exact [capture commands](instructor-guide.md#capture-and-normalize). `capture.py live` performs read-only API queries with explicit subscription/group or project and exact ownership. Its envelope contains `source=live`, `provider`, `scope`, `ownership`, `data`; it refuses to overwrite an existing capture. `normalize.py live` reads that file **without calling APIs**. Neither mode silently substitutes fixtures or turns authentication/API errors into `[]`.

A zero-VM capture is not proof of cleanup. Use the guide's [destruction and residual verification](instructor-guide.md#safe-destruction-and-read-only-verification), including preserved output names and `cleanup.py live`.

## Costs and private files

With authorized Billing access, use Azure **Cost Management + Billing → Cost analysis** to filter subscription/resource group, period, service/region and available tags. In GCP **Cloud Billing → Reports**, filter billing account/project and period, then service/SKU and available labels. Review compute, disks, external IPv4, storage/operations and egress; stopping a VM does not remove all charges. Reports and tags may be delayed, and credits are not proof of free usage.

Review only existing authorized budgets or unsaved forms. **Do not create budgets or send notifications without permission; budgets and alerts do not automatically stop spending.** Without Billing access, compare cost categories offline rather than inventing live prices or invoices.

Keep credentials, keys, `.terraform`, `*.tfstate*`, plans, `.tfvars`, backend files, real captures and outputs out of Git and AI services. Retain private evidence only according to your approved policy. A successful local comparison does not establish image/SKU availability, quotas, permissions, pricing or live cloud correctness.
