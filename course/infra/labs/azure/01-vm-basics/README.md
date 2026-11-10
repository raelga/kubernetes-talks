# Azure VM basics: networking, SSH and a web page

The live Azure demonstration runs in an **instructor account**. Students can follow the [offline Azure/GCP comparison](../../azure-gcp/README.md) without cloud credentials; deployment in a separately approved account is optional. This exercise creates billable resources, including a public IP. HTTP is unencrypted: do not enter or serve sensitive data.

Terraform creates a resource group, virtual network, subnet, network security group (NSG), public IP, network interface and one Ubuntu VM. Cloud-init starts a small HTTP server on port 8080. The NSG permits TCP 22 and 8080 from the selected public IPv4 range and explicitly denies those ports from other sources, including the virtual network. Azure's other default NSG rules remain in place. This is a teaching example, not a production deployment.

## Prerequisites

- Terraform 1.10–1.x, OpenSSH and the Azure authentication setup in the [Azure overview](../README.md). On Windows use PowerShell; on macOS use Terminal.
- An authorized subscription and identity with permission to create and delete the lab resources. Complete the [state lab](../00-terraform-state/README.md) first. Its resource group, storage account and container must already exist in the same approved subscription, and the identity needs **Storage Blob Data Contributor** access to the state container. State uses Azure AD authentication and a distinct key `azure/01-vm-basics.tfstate`.
- Confirm the selected subscription and tenant using the onboarding instructions before beginning; never share credentials, private keys, Terraform state or `.terraform` backend metadata. State may contain infrastructure details and must remain private in encrypted storage.
- Find the public IPv4 address seen by Azure from your current network, including VPN/NAT. Use that address with `/32` as `YOUR_PUBLIC_IP/32`; if it changes, update the variable and apply again. Do not use `0.0.0.0/0`.
- The lab uses fixed names, including resource group `rg-vm-basics`. Ensure they are unused; never reuse a shared resource group. The defaults are `Standard_D2as_v7`, `westeurope`, zone `3`. This VM incurs charges; check current prices and stop/destroy it after the lab. Availability and quota differ by subscription: override `vm_size`, `location` or `zone` if needed.

## 1. Prepare SSH and Terraform variables

Generate a dedicated SSH key if you do not already have one for this lab. Keep the private key on your own machine; choose a passphrase and do not commit either key. If the named key already exists, do not overwrite it; use its public key or choose another path.

macOS:

```sh
ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/azure-vm-basics" -C "vm-basics"
export ARM_SUBSCRIPTION_ID="APPROVED_SUBSCRIPTION_ID"
export TF_VAR_subscription_id="$ARM_SUBSCRIPTION_ID"
export TF_VAR_allowed_source_cidr="YOUR_PUBLIC_IP/32"
export TF_VAR_ssh_public_key="$(cat "$HOME/.ssh/azure-vm-basics.pub")"
```

Windows PowerShell (install the Windows OpenSSH client if needed):

```powershell
ssh-keygen -t rsa -b 4096 -f "$env:USERPROFILE\.ssh\azure-vm-basics" -C "vm-basics"
$env:ARM_SUBSCRIPTION_ID = "APPROVED_SUBSCRIPTION_ID"
$env:TF_VAR_subscription_id = $env:ARM_SUBSCRIPTION_ID
$env:TF_VAR_allowed_source_cidr = "YOUR_PUBLIC_IP/32"
$env:TF_VAR_ssh_public_key = (Get-Content -Raw "$env:USERPROFILE\.ssh\azure-vm-basics.pub").Trim()
```

Replace the placeholders with the approved subscription ID and your public IP. The backend and provider must target that same verified subscription. Repeat the environment setup in any new terminal. Only the **public** key is supplied to Terraform; never put a private key or credentials in a `.tfvars` file, command history or Git.

## 2. Initialize, plan and deploy

From the repository root, use the state lab's actual resource group, storage account and container names (not the VM resource group):

```sh
cd course/infra/labs/azure/01-vm-basics/infra
terraform init -backend-config="resource_group_name=STATE_RESOURCE_GROUP" -backend-config="storage_account_name=STATE_STORAGE_ACCOUNT" -backend-config="container_name=STATE_CONTAINER"
terraform plan
terraform apply
```

Review the plan and approve only the intended lab resources. If changing an existing working directory's backend, follow Terraform's reconfiguration or migration prompts deliberately; do not overwrite another deployment's state. You can set `TF_VAR_location` consistently for all commands if the approved region differs. The VM image, package repositories, subscription policy and outbound connectivity must be available in that region.

After apply, obtain the URL and open it **from the allowed network**:

```sh
terraform output -raw application_url
```

The page should say “Azure VM basics”. Cloud-init may take several minutes after Terraform finishes. HTTP is plain text. NSGs are stateful; higher-level network or organization policies may still block access.

## 3. Connect and inspect

Print the public IP using `terraform output -raw public_ip`. Replace `PUBLIC_IP` below with that value. Before accepting the SSH host key, verify its fingerprint through a trusted out-of-band channel with the instructor; an IP address can be reassigned.

macOS:

```sh
ssh -i "$HOME/.ssh/azure-vm-basics" labuser@PUBLIC_IP
```

Windows PowerShell:

```powershell
ssh -i "$env:USERPROFILE\.ssh\azure-vm-basics" labuser@PUBLIC_IP
```

Inside the VM:

```sh
systemctl status vm-basics.service --no-pager
curl http://localhost:8080/
sudo tail -n 100 /var/log/cloud-init-output.log
exit
```

If the page is unavailable, inspect the cloud-init log and `journalctl -u vm-basics.service --no-pager`, confirm your current public IP and NSG rules, and check policies and outbound access to Ubuntu package repositories. SSH requires the matching private key, TCP 22 from the allowed address and a verified host key.

## 4. Destroy and review costs

In the same local directory and terminal, retaining the same variables (including any location override), run:

```sh
terraform destroy
```

Review the plan before confirming. Confirm in the Azure portal that the lab VM, OS disk, public IP, NIC, NSG, subnet, virtual network and **lab** resource group are gone. Never delete the shared state resource group, storage account or container during this cleanup; retain them according to the [state lab](../00-terraform-state/README.md). Review Azure Cost Management filters and the approved budgets/alerts for VM, disk, public IP and traffic. Billing can lag, and budgets do not automatically stop spending. Delete only resources created for this exercise, not the subscription or shared resources.
