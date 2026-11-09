# Teaching Azure and GCP

Start with the [offline comparison](README.md#1-run-the-offline-comparison). Use the live demo only in approved accounts with working credentials and existing state backends. Fixtures are synthetic, not proof of a deployment.

## What to show

- Same Terraform workflow, different provider resources.
- Azure subscription/resource group versus GCP project.
- A small VM serving `/health`, plus separate private object storage.
- Azure provisioning success is not power state; GCP `TERMINATED` means stopped.

Use one or both providers. Students do not need to deploy both.

## Before the live demo

- Install Bash, Python 3.11+, Terraform `>=1.6,<2` and the selected cloud CLI.
- Confirm account, quota, images and permissions. Azure needs Compute, Network and Storage registered; GCP needs billing and Compute/Storage APIs enabled already.
- Have a private, recoverable backend with approved access. Application storage is not the backend.
- Keep the application storage empty. HTTP uses port 8080 and your IPv4 `/32`; SSH stays blocked.
- Do not enable APIs, register providers or change IAM to get past a denial.

## Remote state and authentication

From the repository root:

```bash
cd course/infra/labs/azure-gcp
export LAB_ROOT="$(pwd -P)"
export EVIDENCE_DIR="$(mktemp -d)"
read -r -p 'Unique lab ID (3–12 lowercase letters/digits/hyphens): ' LAB_ID
read -r -p 'Your public IPv4 CIDR (/32 preferred): ' CLIENT_CIDR
export TF_VAR_lab_id="$LAB_ID" TF_VAR_http_client_cidr="$CLIENT_CIDR"
```

Use a new lab ID and the default workspace. Keep the same inputs and backend through cleanup. Retain provider lockfiles; keep state, plans, captures and credentials private.

### Azure

Use an approved subscription, supported region/SKU and an existing public SSH key. The key does not open SSH. The backend uses Entra authentication and Blob leases, not shared keys.

```bash
az login
read -r -p 'Approved subscription UUID: ' AZ_SUBSCRIPTION
read -r -p 'Approved Azure region: ' AZ_LOCATION
read -r -p 'VM size (Standard_B1s, Standard_B1ms or Standard_B2s): ' AZ_VM_SIZE
read -r -p 'Absolute path to existing PUBLIC SSH key (.pub): ' AZ_PUBLIC_KEY
az account show --subscription "$AZ_SUBSCRIPTION"
export TF_VAR_subscription_id="$AZ_SUBSCRIPTION" TF_VAR_location="$AZ_LOCATION"
export TF_VAR_vm_size="$AZ_VM_SIZE" TF_VAR_ssh_public_key_path="$AZ_PUBLIC_KEY"
read -r -p 'Existing backend resource group: ' AZ_STATE_RG
read -r -p 'Existing backend storage account: ' AZ_STATE_ACCOUNT
read -r -p 'Existing private backend container: ' AZ_STATE_CONTAINER
cd "$LAB_ROOT/azure/terraform"
terraform init \
  -backend-config="subscription_id=$AZ_SUBSCRIPTION" \
  -backend-config="resource_group_name=$AZ_STATE_RG" \
  -backend-config="storage_account_name=$AZ_STATE_ACCOUNT" \
  -backend-config="container_name=$AZ_STATE_CONTAINER" \
  -backend-config="key=upc-2026/cloud-03/$LAB_ID/azure.tfstate" \
  -backend-config="use_azuread_auth=true"
```

The Azure identity needs both resource permissions and Blob data access. Stop if the subscription, backend or existing state is not yours.

### GCP

CLI login and Application Default Credentials are separate. Select the same approved identity in both; Terraform uses ADC. No service-account key is needed.

```bash
gcloud auth login
gcloud auth application-default login
gcloud auth list --filter=status:ACTIVE --format='value(account)'
read -r -p 'Existing approved project ID: ' GCP_PROJECT
read -r -p 'Approved GCP region: ' GCP_REGION
read -r -p 'Zone in that region: ' GCP_ZONE
read -r -p 'Machine type (e2-micro or e2-small): ' GCP_MACHINE_TYPE
read -r -p 'Existing backend bucket (without gs://): ' GCP_STATE_BUCKET
export TF_VAR_project_id="$GCP_PROJECT" TF_VAR_region="$GCP_REGION"
export TF_VAR_zone="$GCP_ZONE" TF_VAR_machine_type="$GCP_MACHINE_TYPE"
gcloud projects describe "$GCP_PROJECT"
cd "$LAB_ROOT/gcp/terraform"
terraform init \
  -backend-config="bucket=$GCP_STATE_BUCKET" \
  -backend-config="prefix=upc-2026/cloud-03/$LAB_ID/gcp"
```

GCS provides Terraform locking. Keep ADC private; do not bypass locks or switch projects to hide a permission error.

## Deploy and open the application

In the selected provider's Terraform directory:

```bash
terraform plan
terraform apply
APP_URL="$(terraform output -raw http_url)"
curl --fail --show-error "$APP_URL/health"
```

Review before approving. Expect that root's network, VM and empty private storage—not IAM, projects or backend creation. The VM installs Python and runs the app as `nobody`; it does not access the storage.

If the page is not ready, check startup logs, outbound connectivity and your current client CIDR. Do not widen SSH or replace a failed response with fixture data.

## Capture and normalize

Optional: compare a real response with the offline fixtures. Run only the provider you deployed; use a fresh output filename when repeating a capture.

```bash
python3 "$LAB_ROOT/scripts/capture.py" live --provider azure --lab-id "$LAB_ID" \
  --subscription "$AZ_SUBSCRIPTION" --resource-group "upc-2026-cloud-03-$LAB_ID" \
  --output "$EVIDENCE_DIR/azure-live.json"
python3 "$LAB_ROOT/scripts/normalize.py" live --provider azure \
  --input "$EVIDENCE_DIR/azure-live.json" --running-only
```

For GCP:

```bash
python3 "$LAB_ROOT/scripts/capture.py" live --provider gcp --lab-id "$LAB_ID" \
  --project "$GCP_PROJECT" --output "$EVIDENCE_DIR/gcp-live.json"
python3 "$LAB_ROOT/scripts/normalize.py" live --provider gcp \
  --input "$EVIDENCE_DIR/gcp-live.json" --running-only
```

Capture reads cloud APIs; normalization reads the saved file. `terraform output -json` is not VM inventory. Keep the existing ownership tags and naming: the capture scripts depend on them.

## Useful follow-up

Change an input, review `terraform plan`, then apply. A client-IP change should update the firewall rule; changing a name may replace resources. Keep the lab ID and backend key stable.

Show the [cost console checklist](README.md#costs-and-private-files): compute, disks, public IPv4, storage and traffic. Billing is delayed; budgets do not stop spending.

## Cleanup

From each provider directory you deployed, with its original inputs and backend:

```bash
terraform destroy
```

Review the deletions, confirm, and wait for completion. Keep application storage empty; do not force-delete unexpected data. Shared backends, subscriptions/projects and local credentials remain. Never delete a whole project or shared resource group as a shortcut.
