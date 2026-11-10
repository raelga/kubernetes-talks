# Terraform: bootstrap an Azure Storage state backend

This optional live lab creates a resource group, Storage account and private Blob container with local Terraform state, then migrates that state to the container. Azure demonstrations use instructor accounts. The backend is shared by the Azure labs, but **each root module must use its own state key**.

## Before you start

- Install Terraform >= 1.10 and < 2.0, and complete the [Azure onboarding](../README.md#sign-in-and-select-a-subscription). Use an approved subscription and verify both its ID and tenant. Never put subscription-specific private configuration, credentials or state in Git.
- Obtain authorization to create Storage resources and an account-scoped role assignment. `Microsoft.Storage` must already be registered. Terraform grants its current identity **Storage Blob Data Contributor** on the new account; the identity needs `Microsoft.Authorization/roleAssignments/write`. RBAC propagation can take time, so a temporary 403 may require waiting before retrying.
- AzureRM uses Microsoft Entra ID for Storage operations (`storage_use_azuread = true`). The backend also uses Entra ID (`use_azuread_auth = true`); shared account keys are disabled. Use the authorized interactive Azure CLI identity from onboarding, or an approved federated OIDC workload identity. For OIDC, configure the provider and backend with the same identity using `ARM_USE_OIDC=true`, `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` and a short-lived OIDC token supplied by your CI environment as described in the [AzureRM backend authentication documentation](https://developer.hashicorp.com/terraform/language/backend/azurerm). Do not put tokens in backend arguments or files.
- The account name gets a random suffix and must be globally unique. The default region is `westeurope`; choose an approved region if different. Storage encrypts data at rest by default; the private container and disabled shared keys do not replace least-privilege RBAC, network controls, or private handling of local state. This lab leaves the public Storage endpoint enabled: restrict connectivity according to your organization's policy before storing sensitive state, and ensure your approved execution environment can reach it.

## 1. Create the backend with local state

After onboarding in the same terminal, enter the verified subscription ID and region, initialize, and review the plan:

```sh
cd course/infra/labs/azure/00-terraform-state
read -r -p 'Approved subscription ID: ' ARM_SUBSCRIPTION_ID
read -r -p 'Approved Azure region (for example westeurope): ' TF_VAR_location
export ARM_SUBSCRIPTION_ID TF_VAR_location
export TF_VAR_subscription_id="$ARM_SUBSCRIPTION_ID"
terraform init
terraform plan
```

The plan should create one resource group, one Storage account, one private container, an account-scoped Blob role assignment, and the random suffix. Confirm the subscription and region before applying:

```sh
terraform apply
terraform state list
terraform output
export STATE_RG="$(terraform output -raw state_resource_group_name)"
export STATE_ACCOUNT="$(terraform output -raw state_storage_account_name)"
export STATE_CONTAINER="$(terraform output -raw state_container_name)"
```

State initially lives in `terraform.tfstate`, and may contain secrets. Protect the directory and backups. The `.gitignore` excludes local state, variable files, backend configuration and common plan files; inspect files before committing. Provider lockfiles can be committed for reproducibility; never commit state, tokens or credentials.

## 2. Migrate to Azure Blob Storage

Backend configuration cannot reference Terraform variables or outputs. Copy the template and provide the values explicitly. `key` is unique to this bootstrap state; other labs use different keys. Migration writes the state only after the container exists and the identity has Blob data access.

```sh
cp backend.tf.example backend.tf
terraform init -migrate-state \
  -backend-config="subscription_id=$ARM_SUBSCRIPTION_ID" \
  -backend-config="resource_group_name=$STATE_RG" \
  -backend-config="storage_account_name=$STATE_ACCOUNT" \
  -backend-config="container_name=$STATE_CONTAINER" \
  -backend-config="key=azure/terraform-state/terraform.tfstate" \
  -backend-config="use_azuread_auth=true"
terraform state list
terraform output
terraform plan
```

Confirm the migration prompt. The output should still name the same resources and the plan should show no changes. If Terraform proposes creating or replacing them, **stop** and inspect the subscription, inputs and both state locations; do not apply. Terraform can retain a local backup: protect it, but do not use it as an independent source of truth. Backend settings are cached in `.terraform`; protect that directory as well. If migration is interrupted, inspect both copies before retrying; never blindly overwrite state.

The backend uses a Blob lease for locking. Do not force-unlock an active operation. For another Azure lab, initialize its backend with the same subscription, resource group, account and container but the distinct key prescribed in that lab. Identity, Blob RBAC and network access are required whenever the backend is used.

## 3. Costs and cleanup

Use Azure Cost Management + Billing to filter the approved subscription, resource group, period and Storage service. Review storage capacity, transactions and traffic, including retained blob versions. Check authorized budgets and alerts; billing reports can be delayed and budgets do **not** automatically stop spending.

**Keep this backend** while any lab uses it, including this bootstrap root. Do not run `terraform destroy` here or delete the resource group, account, container or state blobs during other labs' cleanup. The resource lifecycle blocks accidental Terraform destruction, but not deletion outside Terraform. Once all users have migrated every state and an authorized owner has planned retention and recovery, backend retirement is a separate administrative operation; do not simply remove the safeguards or delete the resources.
