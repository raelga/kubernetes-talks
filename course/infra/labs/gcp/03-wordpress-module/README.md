# WordPress with a local Terraform module on GCP

This optional, **billable** lab deploys the same WordPress architecture as [02-wordpress](../02-wordpress/README.md), using the reusable local module at [`course/infra/modules/gcp/wordpress-stack`](../../../modules/gcp/wordpress-stack). The root configures the Google provider and GCS backend, passes a resource name prefix, region, zone and allowed CIDR to the module, and exposes the prefix, instance name, public IP and database private IP as outputs. Read the module's resources and templates to see how inputs, outputs and `path.module` work; Terraform runs commands from `infra`, not the module directory.

The stack creates a Debian VM with an external IP, a dedicated VPC and firewall, private services access, private Cloud SQL for MySQL, and Secret Manager secrets. It is a disposable teaching environment, not production: no HTTPS, backups or high availability. Do not use real data. Cloud SQL and other resources incur charges even when a VM qualifies for the free tier.

## Prerequisites

- Terraform 1.10–1.x and the Google Cloud CLI; complete the [state bucket lab](../00-terraform-state/README.md). Use an approved billing-enabled project and the [GCP Terraform sign-in](../README.md#sign-in-for-terraform), checking both the CLI account/project and Application Default Credentials. Set `GOOGLE_CLOUD_PROJECT` to the intended project; ADC also needs access to the state bucket.
- Enable Compute Engine, Cloud SQL Admin, Service Networking, Secret Manager and OS Login APIs. Your identity needs permissions to manage these resources, service accounts and secret-level IAM, attach the VM service account (`iam.serviceAccounts.actAs`), and use OS Login. Organization policies may prevent deployment; do not change them just for this lab.
- Determine your current public IPv4 address, including VPN/NAT, and use its `/32` below. The firewall allows SSH and HTTP only from the chosen IPv4 CIDR; update it if your address changes. This lab does not configure IAP.
- Choose a distinct `name_prefix` for each deployment, including deployments in the same project. It must be 3–27 lowercase letters, digits or hyphens, start with a letter and end with a letter or digit. The module derives resource names and the firewall tag from it; check that the resulting names are available. Cloud SQL instance names may remain unavailable for some time after deletion. Each deployment needs sufficient quota and private service address space.

## Deploy and inspect

From the repository root, replace the bucket, state prefix, resource prefix and CIDR with values specific to this deployment (the bucket name has no `gs://`):

```sh
cd course/infra/labs/gcp/03-wordpress-module/infra
terraform init -backend-config="bucket=STATE_BUCKET_NAME" -backend-config="prefix=gcp/wordpress-module/DEPLOYMENT_ID"
terraform plan -var="name_prefix=YOUR_UNIQUE_PREFIX" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
terraform apply -var="name_prefix=YOUR_UNIQUE_PREFIX" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
terraform output
```

Review the plan before confirming. The default region and zone are `us-west1` and `us-west1-b`; if overridden, keep them compatible and supply the same overrides to plan, apply and destroy. Cloud SQL and VM startup can take several minutes. Use a distinct GCS backend prefix and distinct resource `name_prefix` for each deployment, even in the same bucket and project. The default backend prefix is `gcp/wordpress-module`; the example overrides it to isolate this deployment from other copies and from `02-wordpress` (`gcp/wordpress`). Use a separate working directory for each initialized deployment, retain its backend configuration, and run commands against the intended state. Do not migrate, overwrite or share another deployment's state; changing an initialized backend requires deliberate reconfiguration or migration. The database and MySQL application username remain `wordpress`; they are scoped to each SQL instance and are not derived from the prefix.

If upgrading an existing fixed-name deployment, do not apply the new configuration blindly: changing its names can replace resources and destroy data. Preserve its original state and configuration until you have planned an intentional migration or destroyed the old deployment.

## Open the site

The public endpoint is HTTP only. Do not enter passwords over public HTTP. Instead, forward a local port using OS Login (replace the zone if overridden):

```sh
gcloud compute ssh "$(terraform output -raw instance_name)" --zone=us-west1-b -- -L 8080:localhost:80
```

Keep SSH open and visit <http://localhost:8080/>. Complete installation promptly, using a separate disposable WordPress administrator account and password, never a real password. Anyone able to reach HTTP from the allowed CIDR could initialize the site first. WordPress records its installation URL, so continue using the same forwarded address. Close SSH when finished.

Terraform generates database passwords and WordPress salts, stores them in Secret Manager **and sensitive Terraform state**, and grants the VM service account access to the individual secrets. State, its bucket versions and backups, plans, working directories and VM disk need protection; never commit credentials or state. The VM retrieves secrets at startup and connects to private SQL via a CA-verified TLS tunnel. For bootstrap details, troubleshooting, limitations and recovery commands, see [02-wordpress security and troubleshooting](../02-wordpress/README.md#security-and-troubleshooting).

## Destroy and review costs

From the same initialized `infra` directory, use the same prefix, CIDR and any project/region/zone overrides used at apply:

```sh
terraform destroy -var="name_prefix=YOUR_UNIQUE_PREFIX" -var="allowed_source_cidr=YOUR_PUBLIC_IP/32"
```

Review and confirm the plan. This deletes the module lab's VM, disk, database and WordPress data, secrets, network and peering, not the shared bucket or the other lab's resources. Confirm deletion and release of the external IP in the console. Secret Manager retention, GCS object versions and backups can retain sensitive data; follow organizational policy and delete only authorized lab artifacts. Keep the shared state bucket according to the [state lab](../00-terraform-state/README.md).

Review Cloud Billing reports and filters for SQL instance/storage, VM, disk, external IP, traffic, secrets and state storage/operations; set or review approved budgets and alerts. Billing can be delayed and budgets do **not** automatically stop spending. Check prices before deploying; do not delete the shared project or billing account.
