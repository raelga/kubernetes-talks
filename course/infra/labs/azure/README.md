# Azure: CLI and subscription setup

These labs use an approved Azure subscription. The course's Azure demonstration runs in an instructor account; students can use the [offline comparison](../azure-gcp/README.md) without a cloud account.

## Install the Azure CLI

- **macOS:** Follow the [Azure CLI installation guide for macOS](https://learn.microsoft.com/cli/azure/install-azure-cli-macos).
- **Windows:** Follow the [Azure CLI installation guide for Windows](https://learn.microsoft.com/cli/azure/install-azure-cli-windows).

Open a new terminal or PowerShell window and check the installation:

```sh
az version
```

## Sign in and select a subscription

Use your approved account and tenant. Sign in through a browser using an isolated Azure CLI profile; do not use shared token caches.

macOS:

```sh
export AZURE_CONFIG_DIR="$(mktemp -d)"
az login
```

Windows PowerShell:

```powershell
$env:AZURE_CONFIG_DIR = Join-Path $env:TEMP ("azure-lab-" + [guid]::NewGuid())
az config set core.enable_broker_on_windows=false
az login
```

To sign in to a specific tenant, use `az login --tenant TENANT_ID`. Follow your organization's authentication policy. Verify the tenant and subscription before any deployment:

```sh
az account show --subscription SUBSCRIPTION_ID --query '{subscription:id,tenant:tenantId,name:name}' -o json
```

Terraform's AzureRM provider and backend need the same authorized identity and subscription. Set `ARM_SUBSCRIPTION_ID` in your terminal to the approved subscription ID, and follow the authentication instructions in each lab. The backend needs Azure Storage data-plane permissions in addition to resource-management permissions. Never put credentials, state, plans or private variables in Git.

## Prepare Storage for Terraform state

Before lab 00, check that the Storage resource provider is registered in the approved subscription:

```sh
az provider show --namespace Microsoft.Storage --subscription SUBSCRIPTION_ID --query registrationState -o tsv
```

If it is `NotRegistered`, and you are authorized to register providers, run:

```sh
az provider register --namespace Microsoft.Storage --subscription SUBSCRIPTION_ID --wait
```

An enabled subscription can take time to become available to every Azure service. If an API returns `SubscriptionNotFound`, verify the subscription and provider registration rather than switching subscriptions.

The Terraform identity also needs **Blob data-plane access**, such as `Storage Blob Data Contributor` on the state account or an appropriate parent scope. Subscription management roles alone do not necessarily grant Blob access. Ask the subscription administrator to grant the approved role; allow time for permission propagation. Without it, state migration can fail with `403 AuthorizationPermissionMismatch` even if Terraform created the account and container.

## Labs

- [00 · Terraform state in Azure Storage](00-terraform-state/README.md)
- [01 · Virtual machine basics and SSH](01-vm-basics/README.md)
- [02 · WordPress and Azure Database for MySQL](02-wordpress/README.md)
- [03 · WordPress Terraform module](03-wordpress-module/README.md)

Azure resources can incur charges, including disks and public IPs even when a VM is stopped. Review Cost Management filters, budgets and alerts; reporting can lag and budgets do **not** automatically stop spending. Destroy only resources created by a lab; keep the shared state backend while other labs use it.
