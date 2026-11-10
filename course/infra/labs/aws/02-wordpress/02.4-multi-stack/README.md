# 02.4 · WordPress with separate states

## Goal

Split the network, private RDS database and application into three states. Stages 02.5–02.7 reuse the network and database with their own application states.

![Architecture](diagram.png)

[Editable architecture diagram](diagram.drawio)

## Deploy

- Follow the [shared setup](../README.md) in the same terminal, using your state bucket from lab 00. The default region is `us-east-1`.
- You need Terraform >= 1.10 and Academy permissions for S3 locking, EC2, RDS and Secrets Manager. `LabInstanceProfile` needs access to the application and RDS master secrets, the applicable KMS key and, for Session Manager, SSM permissions and connectivity.
- The existing Academy EC2 key pair defaults to `vockey`; obtain its matching PEM from Academy and keep it outside the repository. Set `ssh_key_name` in the WordPress root if the authorized key pair differs. The network root's default `http_cidr` is `0.0.0.0/0`, exposing both HTTP and SSH to the Internet; optionally restrict it to your public IPv4 address as a `/32`.
  For example, before planning or applying the network, run `export TF_VAR_http_cidr="$(curl -4fsS https://checkip.amazonaws.com)/32"`; update it and reapply the network if your public IP changes.
- Apply the network root even if it already exists, to publish the SSH security-group output before planning WordPress. SSH uses a separate group attached only to this single instance; the shared app group remains usable by the later Auto Scaling labs.
- From the `02.4-multi-stack/` directory, deploy in order:

```sh
cd network
terraform init -backend-config="bucket=$TF_VAR_state_bucket"
terraform plan
terraform apply
cd ../database
terraform init -backend-config="bucket=$TF_VAR_state_bucket"
terraform plan
terraform apply
cd ../wordpress
terraform init -backend-config="bucket=$TF_VAR_state_bucket"
terraform plan
terraform apply
terraform output -raw url
```

- Wait for cloud-init and complete setup. HTTP is unencrypted: use synthetic data and disposable passwords. To inspect `/var/log/infra-lab-bootstrap.log`, use Session Manager if authorized or SSH from `wordpress/` with your own PEM:

```sh
chmod 400 /path/to/vockey.pem
ssh -i /path/to/vockey.pem ec2-user@"$(terraform output -raw public_ip)"
```

- The allocated Elastic IP supplies the site URL and survives instance replacement while this state and allocation remain intact. Existing installations using a different URL may require a WordPress URL/content migration; replacing or destroying the allocation changes the address.
- State and retained versions contain secrets. A `terraform_remote_state` reader can access the entire state, not just outputs.

## Experiment

- Create a post and upload an image: the database is in RDS, but uploads are lost when EC2 is replaced.
- Compare network and database outputs with the `terraform_remote_state` references. Re-plan dependent roots after changing a dependency: their locks are independent.

## Clean up

- From `wordpress/`, run `terraform destroy`. This application's database and user remain on RDS until an authorized administrator removes them or RDS is destroyed.
- Keep network and database while using 02.5–02.7. Once **all** dependent applications are destroyed, from `wordpress/`:

```sh
cd ../database
terraform destroy
cd ../network
terraform destroy
```

- Resolve application destroy failures first. RDS has no backups or final snapshot: destruction deletes its data. Check for billable leftovers, including Elastic IPs; public IPv4 addresses incur charges even when an Elastic IP is unassociated. Retain the state bucket as directed in lab 00.
