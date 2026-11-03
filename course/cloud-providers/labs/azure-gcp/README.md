# 03 · Azure and GCP: multicloud and IaC transfer

**10/11/2026 · Rael Garcia · 18:00–21:00 Europe/Madrid · M2, with 60 integrated minutes of M1.**

Students **do not need Azure/GCP accounts and do not deploy resources**. They analyze two prepared instructor demonstrations and adapt Python using local **synthetic** responses. No cloud deployment was performed to prepare these files. Real accounts, permissions, quotas, images, regions and prices must be checked before class: [instructor guide](instructor-guide.md).

## Required objective and scope

Transfer the AWS use case: a dedicated network + a small VM serving HTTP JSON using standard-library Python on port 8080 + empty, **private** object storage, separate from the application. No Docker, Kubernetes, VM access to the bucket, startup keys or IAM changes. The same intent does not make resources interchangeable. Terraform shares a language and workflow, not state or APIs across providers.

Global storage names receive a random suffix persisted in state by default: 8 hexadecimal characters for Azure (`upc3` + lab_id without hyphens + suffix, at most 24 characters) and 12 for GCP (project + `-c03-` + lab_id + suffix, at most 60). The same state preserves the name; independent states generate different suffixes. Networks, resource groups and VMs still require a unique `lab_id`. `storage_account_name` (Azure) and `bucket_name` (GCP), both defaulting to `null`, accept an exact globally available name and skip suffix generation; they do not adopt existing resources. Changing these values can replace storage: review the plan and always read actual names from outputs, never reconstruct them.

Deliver a reasoned equivalence table, an AI-reviewed Python adaptation and local evidence of filtering running resources. Cloud demonstrations belong to the instructor; these are not two account-registration labs. No Final Project requirements or grading percentages are added.

### Exact 180-minute agenda

| Time | Minutes | Activity |
|---|---:|---|
| 18:00–18:10 | 10 | Recall AWS; identity, network, VM, storage and instructor/student scope |
| 18:10–18:35 | 25 | Azure demonstration: prepared plan, resources, HTTP response, private Blob storage |
| 18:35–18:53 | 18 | Azure Cost Management: filters, budget, alerts and cleanup |
| 18:53–19:18 | 25 | GCP demonstration: project, regional/zonal VPC resources, VM and private bucket |
| 19:18–19:36 | 18 | GCP Cloud Billing: filters, budget, alerts and cleanup |
| 19:36–20:36 | 60 | **M1: Python, configuration, comparison and AI-assisted review**, without credentials |
| 20:36–20:51 | 15 | Variables, modules, outputs, remote state and locking in both backends |
| 20:51–21:00 | 9 | Prepared instructor destroy, residual-resource verification and conclusions |

The instructor may start VMs before class and prepare plans/evidence to avoid provisioning delays. Perform and verify destroy even when using prepared evidence; if nothing was deployed, explicitly explain that there were no resources to destroy. Do not deploy to “test the materials”.

## Student local preparation

Python **3.11+** and an editor; no external Python dependencies, Terraform or cloud CLI are required for the local activity. The instructor also needs Terraform **>=1.6,<2**, Azure CLI and Google Cloud CLI. From the repository root:

```sh
cd course/cloud-providers/labs/azure-gcp
python3 --version
python3 scripts/normalize.py fixture --provider azure
python3 scripts/normalize.py fixture --provider gcp --running-only
python3 scripts/normalize.py fixture --provider aws --running-only
```

`fixture` never calls APIs or needs credentials. It prints provenance to stderr and JSON to stdout. Observe the app locally without cloud access: `HTTP_HOST=127.0.0.1 python3 app.py`; in another terminal, `curl --fail http://127.0.0.1:8080/health`; stop it with Ctrl-C. Do not expose the local port to other networks. Both VM templates insert this same `app.py`, not a separate implementation.

## Transfer map

| Intent | AWS (session 2) | Azure | GCP |
|---|---|---|---|
| Identity and scope | Account, temporary Academy principal, IAM | Microsoft Entra tenant, subscription, resource group, RBAC | Organization/folder/project, principal, IAM |
| Network | Regional VPC, zonal subnet, instance SG | Regional VNet, subnet, NIC-associated NSG | Global VPC, regional subnet, network-tag-targeted firewall |
| VM | EC2 + AMI + type + AZ | Linux VM + image + SKU + region | Compute Engine + image + machine type + zone |
| Private objects | S3 + public access blocking | LRS Storage Account + private container, no shared keys | Cloud Storage, uniform access and public access prevention |
| Image registry (equivalence only) | ECR | ACR | Artifact Registry |
| Managed services (not deployed) | RDS / EKS | Azure Database / AKS | Cloud SQL / GKE |
| Management boundary | Tagged resources | Dedicated group and tags | Explicit project and labels; do not create/delete the project |

An Azure VM is not running just because `provisioningState` is `Succeeded`. Power state comes from `powerState` (`VM running`, `VM deallocated`) or the `PowerState/...` code in `instanceView.statuses`. In GCP, `status=RUNNING` means running and `TERMINATED` means stopped, not a deleted resource. Azure `location` is a region, GCP `zone` is a zone, AWS `AvailabilityZone` is a zone: **location preserves the provider's value rather than inventing regional equivalence**.

## M1 practice · 60 minutes

1. **0–10 min: inspect contracts.** Read `fixtures/*.json` and `scripts/normalize.py`. Identify name, location and power-state paths. Each fixture is an envelope `{source, provider, description, data}`: `source=synthetic` identifies invented data; `data` is a subset of the CLI response, not a real capture. Azure represents `az vm list --show-details`, GCP `gcloud compute instances list --format=json`, AWS `aws ec2 describe-instances` (comparison, no new AWS deployment).
2. **10–25 min: adapt.** Write a local copy outside the repository or your own function taking a provider and its response and returning records with **only** `provider`, `name`, `location`, `state`. Keep provenance separate from these four fields; sort deterministically. Inspect the solved adapter after attempting your adaptation. The schema accepts `running`, `stopped`, `pending`, `stopping`, `suspended`, `terminated`, `unknown`; an unknown value must not become `running`.
3. **25–40 min: filter and compare.** Implement `running-only` against the common schema, not different provider fields. Run all three fixtures and compare with the results below. Include Azure `Succeeded` without `powerState`: it must yield `unknown` and **not** pass the filter. Check that a valid empty list produces `[]`, whereas invalid JSON fails with a nonzero exit code.
4. **40–50 min: AI under review.** Ask the assistant: “Propose a standard-library Python function adapting these three schemas, without running cloud commands or requesting credentials. Do not confuse provisioning state with power state; justify every field and the handling of unknowns.” Share only synthetic fixtures and code, never private captures, tokens, Terraform state or instructor account identifiers. Review the proposal, identify a specific error/risk and correct it; the model is not an API source of truth.
5. **50–60 min: transfer configuration and explain.** Locate equivalent and non-equivalent variables in both Terraform roots; explain why GCP requires project/region/zone and Azure a **public** key even though SSH is not open. Submit normalized outputs, filter results, an equivalence table and a brief AI-review decision. Do not copy `description` or original responses as expected results.

### Expected semantic results (not source-copy tests)

| provider | name | location | state | Passes `running-only` |
|---|---|---|---|---|
| aws | aws-demo-running | eu-west-1a | running | yes |
| aws | aws-demo-stopped | eu-west-1b | stopped | no |
| azure | azure-demo-running | westeurope | running | yes |
| azure | azure-demo-stopped | westeurope | stopped | no |
| azure | azure-demo-unknown | westeurope | unknown | no |
| gcp | gcp-demo-running | europe-west1-b | running | yes |
| gcp | gcp-demo-stopped | europe-west1-b | stopped | no |

## What to observe during demonstrations

- Read the plan before `apply`: only this use case's resources; no IAM, enabled APIs, accounts/projects, Kubernetes or new backends. Names use `upc-2026-cloud-03-<lab_id>`; tags/labels are `course=upc-2026`, `lab=cloud-03`, with an instructor-selected `lab_id`. Some GCP resources do not support labels and are identified by exact name/prefix.
- Explicit HTTP CIDR /24–/32, preferably instructor IP /32; never `0.0.0.0/0`. TCP 8080 only. Azure denies other inbound traffic, including SSH; GCP creates no SSH rule and uses a new VPC without default rules. The Azure key is public, never private. These are not public production applications or encrypted traffic.
- Read `terraform output -json`: an output envelope with `value`, `type`, `sensitive`, not the inventory schema. Example: `json.load(...)["http_url"]["value"]`. Do not normalize it as a VM response.
- VMs use system Python, user `nobody` and systemd; initial package downloads require outbound Internet access. They use no cloud SDKs or storage access. A running VM may not have HTTP ready: check `/health` separately rather than claiming state implies health.
- `azure/terraform` and `gcp/terraform` are **independent root modules**, each with providers, inputs, outputs and state. Draw a possible child-module boundary (network or application), its inputs/outputs and provider-specific limits. There is no universal module hiding differences; creating an artificial child module is not required. Locate `templatefile` and distinguish it from `module`.
- Remote state lives in **existing instructor backends**, never demonstration buckets: Blob with lease locking and GCS with Terraform locking. The key/prefix includes lab_id and provider. Discuss two plans competing for **the same** state only through explanation/prepared evidence; never remove an active lock or simulate contention on shared state. Setup: [instructor guide](instructor-guide.md#remote-state-and-instructor-authentication).

## Costs: two separate activities

**Azure, 18 min.** The instructor opens *Cost Management + Billing → Cost analysis* at the instructor subscription scope, selects the current month and actual cost, filters the dedicated group and then service/region/tag `lab_id` where available. Compare VM, OS disk, Standard public IP, LRS storage, operations and outbound traffic. Change grouping by service and date; new charges and tags may take time to appear. In *Budgets*, review an existing instructor budget (or explain the form without saving): amount and period, scope/filters, actual and forecast spending thresholds, channel and verified recipient. Do not send alerts or create budgets as a script side effect. Relate the threshold to spending that could accumulate before the alert arrives; record which resources remain after stopping the VM and which require destroy.

**GCP, 18 min.** Open the *Cloud Billing → Reports* account view, filter instructor project and period, group by service/SKU; review Compute Engine, Persistent Disk, external IPv4, Cloud Storage and egress. Add label filters where available in the report; do not assume every charge or resource has labels. In *Budgets & alerts*, review an existing instructor budget or the unsaved form: project, period, amount, actual/forecast thresholds and authorized billing-account recipients, checking who would receive the email without sending notifications. Explain credits versus gross cost and that region/type/usage affect price. Destroying a VM is insufficient if disks, IPs or buckets remain.

For both: **billing is delayed; budgets/alerts do NOT automatically stop spending**. Do not promise a free tier. If the instructor lacks Billing access or charges have not appeared, use the guide's synthetic worksheets, explicitly stating they are neither invoices nor current prices. Academy belongs to AWS: its indicators and limits do not transfer to Azure/GCP or guarantee a universal shutdown.

## Clearly separated real captures

Only the instructor, with authorization and from this directory, may run `scripts/capture.py live`. Full authentication, variable and backend instructions are in the guide. Capture performs **read-only** queries with explicit project or subscription/group and exact ownership selection; it neither modifies resources nor uses synthetic fallback:

```sh
python3 scripts/capture.py live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION" --resource-group "upc-2026-cloud-03-$LAB_ID" \
  --output "$EVIDENCE_DIR/azure-live.json"
python3 scripts/capture.py live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --output "$EVIDENCE_DIR/gcp-live.json"
python3 scripts/normalize.py live --provider azure --input "$EVIDENCE_DIR/azure-live.json" --running-only
python3 scripts/normalize.py live --provider gcp --input "$EVIDENCE_DIR/gcp-live.json" --running-only
```

The captured envelope contains `source=live`, `provider`, `scope`, `ownership`, `data`. `normalize.py live` processes the file and **does not call the API**: only `capture.py live` queries it. Neither mode converts authentication/API errors to `[]`; errors are explicit. A capture of zero VMs does not prove that no other resources remain: use `scripts/cleanup.py live` and state review for cleanup, as explained in the guide. Captures/outputs may contain account data: keep them out of Git and do not share them with AI services.

## Evidence and limits

Keep only local credential-free deliverables; do not commit `.terraform`, `*.tfstate*`, plans, real captures, outputs, `.tfvars`, backend files or keys. These materials claim no real deployment or cloud verification. Backend/image/SKU/quota/price depend on the instructor environment. Optional extensions outside the 180 minutes: discuss a child module or briefly compare Pulumi/OpenTofu. They are not requirements or substitutes for this practice.
