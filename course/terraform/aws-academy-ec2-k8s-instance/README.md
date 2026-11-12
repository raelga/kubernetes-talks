# AWS Academy Kubernetes EC2 instance

## AutoDeploy using AWS Academy Learner Lab or CloudShell console

```bash
curl -sqL https://bit.ly/k8s-academy-ec2-klab-start | bash
```

## 0. Create the stack in AWS (Terminal 1)

From this directory, initialize and deploy:

```bash
terraform init && terraform apply
terraform output -raw ssh_cmd
```

By default, SSH, application ports and NodePorts are open to the internet (`0.0.0.0/0`). To restrict access to your current public IPv4, set `export TF_VAR_ingress_cidr="$(curl -4fsS https://checkip.amazonaws.com)/32"` before applying. If your IP changes, update it and apply again; use your workstation's IP, not the CloudShell IP.

The local Terraform state contains the generated private SSH key. Keep the state and its backups private, and never commit or share them. By default, the instance has no IAM profile; configure temporary Academy credentials separately when needed.

Docker starts automatically after reboot. If bootstrap fails, inspect `sudo cat /var/log/upc-bootstrap.log` and `sudo cloud-init status --long`.

### Optional: ECR repository

To create a private repository and attach the existing `LabInstanceProfile`, use:

```bash
terraform apply -var="ecr=true"
terraform output -raw ecr_repository_url
```

On the instance, authenticate Docker in the same region:

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com"
```

The login token expires after 12 hours. Empty the repository before destroying the stack. Keep `-var="ecr=true"` (or `TF_VAR_ecr=true`) for subsequent plans and applies while using the repository; reverting to `false` removes the profile and plans to delete the repository.

## 1. Clone the repo

```
git clone --depth 1 https://github.com/raelga/kubernetes-talks.git
```

## 2. Configure AWS credentials

https://awsacademy.instructure.com/courses/64811/modules/items/5739658

```
aws configure set region us-east-1 && nano ~/.aws/credentials
```

Check current user:

```
aws sts get-caller-identity
```

Should look something like:

```
{
    "UserId": "AROAW31NOTSECRET1S4E4:user12345=Rael_Garcia", # notsecret
    "Account": "41231231234",
    "Arn": "arn:aws:sts::41231231234:assumed-role/voclabs/user12345=Rael_Garcia"
}
```
