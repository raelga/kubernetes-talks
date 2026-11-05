# Azure/GCP: optional authorized live walkthrough

The [offline comparison](README.md#1-run-the-offline-comparison) needs no accounts. This path creates **billable resources** in your own approved scope; use only providers for which you have authorization. Do not run it as repository validation. Synthetic [fixtures](fixtures/) are not live evidence, and these instructions make no claim of verified cloud execution.

## Environment and permissions preflight

- Use Bash, Python >=3.11, Terraform >=1.6,<2, and Azure CLI and/or Google Cloud CLI. Provider constraints and resources are defined in [Azure main.tf](azure/terraform/main.tf) and [GCP main.tf](gcp/terraform/main.tf); retain reviewed dependency lockfiles, not caches or credentials. Do not upgrade providers incidentally.
- **Azure:** approved tenant/subscription, region, small-SKU quota and Canonical `ubuntu-24_04-lts/server` image availability. Microsoft.Compute, Network and Storage must already be registered; automatic registration is disabled. Existing permissions must cover creation/deletion in the approved scope and Entra Blob data access for the backend and application container. Shared keys are disabled. Do not add roles, identities or registrations to bypass denial.
- **GCP:** existing approved project with billing, Compute Engine and Cloud Storage APIs already enabled, regional/zonal quota for `e2-micro` or `e2-small`, `debian-cloud/debian-12` image, and existing network/bucket permissions. Do not create projects, enable APIs or change IAM. The VM has no service account or storage access; organizational identity requirements need prior approval, not improvised keys/roles.
- HTTP must be restricted to your outbound IPv4 /24–/32, preferably /32. Check inherited policies: Azure denies other inbound traffic, and GCP creates a dedicated VPC without default rules. A changing VPN/proxy address calls for a reviewed CIDR update, not global HTTP/SSH access.
- Backends must **already exist**, with approved access and versioning/recovery. Never use application storage for state. Use a unique `lab_id`, provider-specific key/prefix and the `default` workspace; do not share these with another operator. Locking protects writers to the same state, not separate states targeting the same resources.

## Remote state and authentication

From the repository root, establish absolute paths so later `cd` commands cannot redirect scripts or evidence:

```bash
cd course/cloud-providers/labs/azure-gcp
export LAB_ROOT="$(pwd -P)"
export EVIDENCE_DIR="$(mktemp -d)"
printf 'Private evidence directory: %s\n' "$EVIDENCE_DIR"
python3 --version
terraform version
read -r -p 'Unique lab_id (3–12 lowercase letters/digits/hyphens, letter first, alphanumeric last): ' LAB_ID
read -r -p 'Your outbound IPv4 CIDR (/32 preferred, /24–/32): ' CLIENT_CIDR
export LAB_ID CLIENT_CIDR
export TF_VAR_lab_id="$LAB_ID" TF_VAR_http_client_cidr="$CLIENT_CIDR"
```

Use only the selected authorized credentials for both provider and backend; check for conflicting credential environment overrides. Names/tags and state paths containing `upc-2026`/`cloud-03` are script contracts, not optional display labels.

### Azure: interactive identity and Blob locking

Use an existing public SSH key and enter an **absolute path** (or a `~/` path). No private key enters Terraform; this key does not open SSH.

```bash
az version
az login
read -r -p 'Approved subscription UUID: ' AZ_SUBSCRIPTION
read -r -p 'Approved Azure region: ' AZ_LOCATION
read -r -p 'Approved SKU (Standard_B1s, Standard_B1ms or Standard_B2s): ' AZ_VM_SIZE
read -r -p 'Absolute path to existing PUBLIC SSH key (.pub): ' AZ_PUBLIC_KEY
export AZ_SUBSCRIPTION AZ_LOCATION
export TF_VAR_subscription_id="$AZ_SUBSCRIPTION" TF_VAR_location="$AZ_LOCATION"
export TF_VAR_vm_size="$AZ_VM_SIZE" TF_VAR_ssh_public_key_path="$AZ_PUBLIC_KEY"
az account show --subscription "$AZ_SUBSCRIPTION" --output json
az vm list-skus --location "$AZ_LOCATION" --size "$AZ_VM_SIZE" \
  --subscription "$AZ_SUBSCRIPTION" --output table
az vm image show --location "$AZ_LOCATION" \
  --urn Canonical:ubuntu-24_04-lts:server:latest --subscription "$AZ_SUBSCRIPTION"

read -r -p 'EXISTING backend resource group (same subscription): ' AZ_STATE_RG
read -r -p 'EXISTING backend storage account: ' AZ_STATE_ACCOUNT
read -r -p 'EXISTING private backend container: ' AZ_STATE_CONTAINER
az storage account show --subscription "$AZ_SUBSCRIPTION" --resource-group "$AZ_STATE_RG" \
  --name "$AZ_STATE_ACCOUNT" --output json
az storage container show --account-name "$AZ_STATE_ACCOUNT" --name "$AZ_STATE_CONTAINER" \
  --auth-mode login --output json
cd "$LAB_ROOT/azure/terraform"
terraform init \
  -backend-config="subscription_id=$AZ_SUBSCRIPTION" \
  -backend-config="resource_group_name=$AZ_STATE_RG" \
  -backend-config="storage_account_name=$AZ_STATE_ACCOUNT" \
  -backend-config="container_name=$AZ_STATE_CONTAINER" \
  -backend-config="key=upc-2026/cloud-03/$LAB_ID/azure.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform workspace show
```

Confirm the account belongs to the subscription tenant, the SKU has quota and image/policy requirements are satisfied. Backend authentication uses CLI/Entra, not shared keys; Blob leases provide locking. `init` must succeed and the workspace must be `default`. If unexpected state or backend configuration exists, **stop and resolve ownership**. Do not automatically import/delete resources, migrate/reconfigure state, delete leases or force-unlock to hide a discrepancy.

### GCP: CLI credentials, ADC and GCS locking

CLI login and Application Default Credentials (ADC) are separate stores. Select the same approved principal in both authentication flows; Terraform uses ADC, not simply the active CLI login. Resolve any organizational ADC quota-project requirement beforehand, without creating accounts, keys or enabling APIs.

```bash
gcloud version
gcloud auth login
gcloud auth application-default login
gcloud auth list --filter=status:ACTIVE --format='value(account)'
read -r -p 'Existing approved project ID: ' GCP_PROJECT
read -r -p 'Approved GCP region: ' GCP_REGION
read -r -p 'Zone in that region with quota: ' GCP_ZONE
read -r -p 'Approved machine type (e2-micro or e2-small): ' GCP_MACHINE_TYPE
read -r -p 'EXISTING GCS backend bucket (name only, no gs://): ' GCP_STATE_BUCKET
export GCP_PROJECT GCP_REGION GCP_ZONE
export TF_VAR_project_id="$GCP_PROJECT" TF_VAR_region="$GCP_REGION" TF_VAR_zone="$GCP_ZONE"
export TF_VAR_machine_type="$GCP_MACHINE_TYPE"
gcloud projects describe "$GCP_PROJECT" --format=json
gcloud services list --enabled --project "$GCP_PROJECT"
gcloud compute zones describe "$GCP_ZONE" --project "$GCP_PROJECT"
gcloud storage buckets describe "gs://$GCP_STATE_BUCKET" --project "$GCP_PROJECT" --format=json
cd "$LAB_ROOT/gcp/terraform"
terraform init \
  -backend-config="bucket=$GCP_STATE_BUCKET" \
  -backend-config="prefix=upc-2026/cloud-03/$LAB_ID/gcp"
terraform workspace show
```

Keep ADC local; never export a service-account key. Confirm bucket versioning/recovery and permissions; GCS provides Terraform locking. The explicit project and bucket/prefix do not rely on `gcloud config set project`. Require `default` workspace and the same ownership checks as Azure. If authentication, permissions, quota or policy checks fail, stop this live path; use clearly identified fixtures instead, never a synthetic fallback presented as live.

## Plan, apply and HTTP verification

Before either apply, inspect state and the complete plan: only the selected root's network, VM, empty private storage and supporting resources may be changed. No IAM, APIs, projects/accounts or backends are created. Stop on unrelated state/resources. Apply only the exact reviewed plan; all commands below incur charges after confirmation.

### Azure

```bash
cd "$LAB_ROOT/azure/terraform"
terraform state list
terraform plan -lock-timeout=60s -out="$EVIDENCE_DIR/azure.tfplan"
terraform show "$EVIDENCE_DIR/azure.tfplan"
# Continue only after approving this exact plan.
terraform apply -lock-timeout=60s "$EVIDENCE_DIR/azure.tfplan"
terraform output -json > "$EVIDENCE_DIR/azure-outputs.json"
AZ_URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["http_url"]["value"])' "$EVIDENCE_DIR/azure-outputs.json")"
curl --fail --show-error "$AZ_URL/health"
```

Check the dedicated group, VNet/subnet, NSG/NIC association, static Standard public IP, VM/OS disk and private LRS storage. The container permits no anonymous content or shared keys; the provider uses your approved identity. “Private” means nonpublic data, not a Private Endpoint. Keep the container empty.

### GCP

```bash
cd "$LAB_ROOT/gcp/terraform"
terraform state list
terraform plan -lock-timeout=60s -out="$EVIDENCE_DIR/gcp.tfplan"
terraform show "$EVIDENCE_DIR/gcp.tfplan"
# Continue only after approving this exact plan.
terraform apply -lock-timeout=60s "$EVIDENCE_DIR/gcp.tfplan"
terraform output -json > "$EVIDENCE_DIR/gcp-outputs.json"
GCP_URL="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["http_url"]["value"])' "$EVIDENCE_DIR/gcp-outputs.json")"
curl --fail --show-error "$GCP_URL/health"
```

Check the global VPC, regional subnet, TCP8080-only network-tag-targeted firewall, zonal VM, standard disk and ephemeral external IPv4. No SSH rule, VM service account or administrative roles are created. OS Login is configured but does not grant access. The bucket enforces public access prevention and uniform access, with `force_destroy=false`; do not upload objects or grant public access.

Both templates embed [app.py](app.py), install Python and run systemd as `nobody`. A successful apply or running VM does not prove package downloads or startup completed. If HTTP fails, inspect authorized cloud-init/startup/serial-console information, outbound connectivity, your actual outbound CIDR and the systemd service. Keep the failure visible; never widen SSH/HTTP to the Internet. Clean up even when startup fails.

## Capture and normalize

Use new output filenames for each capture; the script refuses overwrites. Run only the provider you configured:

```bash
python3 "$LAB_ROOT/scripts/capture.py" live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION" --resource-group "upc-2026-cloud-03-$LAB_ID" \
  --output "$EVIDENCE_DIR/azure-live.json"
python3 "$LAB_ROOT/scripts/normalize.py" live --provider azure \
  --input "$EVIDENCE_DIR/azure-live.json" --running-only

python3 "$LAB_ROOT/scripts/capture.py" live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --output "$EVIDENCE_DIR/gcp-live.json"
python3 "$LAB_ROOT/scripts/normalize.py" live --provider gcp \
  --input "$EVIDENCE_DIR/gcp-live.json" --running-only
```

Capture is read-only, scopes queries explicitly and requires exact tags/labels `course=upc-2026`, `lab=cloud-03`, `lab_id=$LAB_ID`. Azure additionally requires the exact group `upc-2026-cloud-03-$LAB_ID`. The live envelope records `source`, `provider`, `scope`, `ownership`, `data`; normalization reads the file without API calls. API/authentication failures are nonzero errors, not empty successes or fixture fallbacks. See [state semantics](README.md#3-understand-normalized-results): Azure provisioning success is not power state, and GCP `TERMINATED` maps to stopped.

`terraform output -json` is a different envelope with `value`, `type`, `sensitive`; it is not VM inventory and must not be passed to the normalizer. Preserve its actual storage names for cleanup rather than reconstructing them.

## Change configuration

For a permitted change, update an input from the provider's `variables.tf`, then review a fresh plan. For example, after a VPN change, update both roots' shared CIDR input but apply only the roots you actually deployed:

```bash
read -r -p 'New approved outbound IPv4 CIDR (/24–/32): ' CLIENT_CIDR
export TF_VAR_http_client_cidr="$CLIENT_CIDR"
cd "$LAB_ROOT/azure/terraform"  # Use "$LAB_ROOT/gcp/terraform" for GCP instead.
terraform plan -lock-timeout=60s -out="$EVIDENCE_DIR/change.tfplan"
terraform show "$EVIDENCE_DIR/change.tfplan"
# Continue only after approving the exact changes/replacements.
terraform apply -lock-timeout=60s "$EVIDENCE_DIR/change.tfplan"
```

Repeat the relevant output/HTTP commands and capture to a new filename. Do not reuse an old plan after changing inputs. Keep `lab_id` and backend identity stable; changing them can target or replace different resources.

Global storage names default to state-persisted random suffixes: Azure uses `upc3` + lab_id without hyphens + 8 hexadecimal characters (at most 24 total); GCP uses project + `-c03-` + lab_id + 12 hexadecimal characters (at most 60). The same state preserves names, independent states generate different ones, and network/group/VM names still require a unique `lab_id`. Optional `storage_account_name`/`bucket_name` inputs accept a new globally available name, not adoption of existing storage; changing them can replace storage. Always inspect the plan and use outputs.

For costs, follow the [short console checklist](README.md#costs-and-private-files). Do not promise free usage, create budgets or send notifications without permission. Reports are delayed; budgets/alerts do not stop spending. State/plans can be sensitive even when outputs are not marked `sensitive`. Never expose them to AI services or provoke contention in shared state; do not bypass an active lock.

## Safe destruction and read-only verification

Use only the exact root, backend, `lab_id` and `default` workspace you deployed. Preserve outputs first. **Never use `az group delete`, delete the project/backend bucket or clean shared resources.** Inspect the complete destroy plan and interactive confirmation; do not use `-auto-approve`.

Azure account deletion can remove data without a protective `force_destroy` switch. The Blob query must succeed and show `[]`, including deleted blobs, snapshots and versions. If unexpected content appears, stop, confirm ownership and preserve it; do not empty storage to force deletion.

```bash
AZ_STORAGE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["storage_account"]["value"])' "$EVIDENCE_DIR/azure-outputs.json")"
az storage blob list --account-name "$AZ_STORAGE" --container-name private \
  --auth-mode login --include d s v --output json
cd "$LAB_ROOT/azure/terraform"
terraform workspace show
terraform state list
terraform plan -destroy -lock-timeout=60s
terraform destroy -lock-timeout=60s
terraform state list
python3 "$LAB_ROOT/scripts/cleanup.py" live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION"
```

For GCP, confirm bucket accessibility and inspect objects/versions before destroying:

```bash
GCP_BUCKET="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["bucket_name"]["value"])' "$EVIDENCE_DIR/gcp-outputs.json")"
gcloud storage buckets describe "gs://$GCP_BUCKET" --project "$GCP_PROJECT" --format=json
gcloud storage ls --all-versions "gs://$GCP_BUCKET/**" --project "$GCP_PROJECT"
cd "$LAB_ROOT/gcp/terraform"
terraform workspace show
terraform state list
terraform plan -destroy -lock-timeout=60s
terraform destroy -lock-timeout=60s
terraform state list
python3 "$LAB_ROOT/scripts/cleanup.py" live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --bucket "$GCP_BUCKET"
```

A GCP “no matched objects” result is not a permission/API failure: distinguish them and confirm access with `describe`. Keep `force_destroy=false`; do not change it to erase unexpected data. Review soft-delete/retention policies, duration and costs even after active resources disappear.

The residual verifier deletes nothing:

| Provider | Queried scope |
|---|---|
| Azure | Exact dedicated group, then all resources in it if it remains, not only tagged VMs |
| GCP | VMs, disks, addresses, VPC, subnets and firewalls by exact lab name/prefix; the exact preserved bucket in the explicit project |

A nonzero residual result requires investigation against the exact state, not blind deletion. API errors produce **VERIFICATION INCOMPLETE**, never “zero resources”. Query again after eventual consistency without hiding failures. Empty VM capture/state alone is insufficient; the verifier does not audit unrelated services, provider-retained data or closed bills.

Destroy leaves backends, old state versions and local credentials intact. Keep private cleanup evidence outside Git only for your approved retention period; remove it according to policy. Do not commit keys, credentials, `.terraform`, state/plans, `.tfvars`, backend configuration, outputs or live captures. If access is lost, mark verification incomplete and finish authorized cleanup when access is restored; offline fixtures do not resolve live leftovers.
