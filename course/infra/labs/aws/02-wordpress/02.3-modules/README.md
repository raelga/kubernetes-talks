# 02.3 · WordPress with Terraform modules

## Goal

Reuse network, MySQL RDS and WordPress EC2 modules in one root and state. The local database module uses the [community RDS module](https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/6.12.0), pinned to `6.12.0` and downloaded by `terraform init`.

![Architecture](diagram.png)

[Editable architecture diagram](diagram.drawio)

## Deploy

- Follow the [shared setup and safety guidance](../README.md) in the same terminal. You need Terraform >= 1.10 and Academy permissions for S3 locking, EC2, RDS and Secrets Manager.
- `LabInstanceProfile` must read the application and RDS master secrets and use the applicable KMS key. Session Manager also requires SSM permissions and connectivity. The instructor can authorize another profile via `-var="instance_profile_name=..."`.
- From this directory:

```sh
terraform init -backend-config="bucket=$TF_VAR_state_bucket"
terraform plan
terraform apply
terraform output -raw url
```

- Wait for cloud-init and complete setup. HTTP is open to the Internet and unencrypted: use synthetic data and disposable passwords. If authorized, inspect `/var/log/infra-lab-bootstrap.log` through Session Manager.
- State and retained versions contain the application password and salts; do not share or commit state or plans.

## Experiment

- Create a post and upload an image. Uploads remain on EC2 and are lost on replacement; records are in RDS.
- Inspect `main.tf` to see how network and database outputs connect the modules.

## Clean up

- Run `terraform destroy`. RDS has no backups or final snapshot: its data is lost.
- Check for billable EC2, RDS, volume and secret leftovers. Keep the shared state bucket and protect its retained versions.
