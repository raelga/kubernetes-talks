# WordPress as a Terraform module

This lab deploys the same Azure WordPress architecture as [lab 02](../02-wordpress/README.md), but calls the reusable [wordpress-stack module](../../../modules/azure/wordpress-stack). Complete the [Azure onboarding](../README.md) and [state backend lab](../00-terraform-state/README.md) first.

Follow lab 02's prerequisites, authentication and backend initialization from this lab's directory. Use the same backend resource group, Storage account and container, but **do not override the default state key**: this lab uses `azure/wordpress-module/terraform.tfstate` and lab 02 uses a different key.

```sh
cd course/infra/labs/azure/03-wordpress-module
terraform init -backend-config="resource_group_name=STATE_RG" -backend-config="storage_account_name=STATE_ACCOUNT" -backend-config="container_name=STATE_CONTAINER" -backend-config="subscription_id=SUBSCRIPTION_ID"
terraform plan
terraform apply
terraform output wordpress_url
```

Supply the same subscription, SSH public key and restricted public IP inputs described in lab 02. Review the plan before applying. Terraform state and saved plans contain sensitive passwords: restrict backend access and never commit them. The VM, managed database, disks and networking may incur charges.

To deploy another instance, use a separate Terraform working directory and state key. The module generates a distinct resource suffix for each state. Destroy only the deployment in the current state:

```sh
terraform destroy
```

Keep the shared backend and other lab deployments. See lab 02 for access, troubleshooting and cleanup details.
