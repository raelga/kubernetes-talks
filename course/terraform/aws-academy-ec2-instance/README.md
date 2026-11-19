# Notes

## AutoDeploy using AWS Academy Learner Lab or CloudShell console

```bash
curl -sqL http://go.rael.dev/k8s-academy-ec2-llab-start | bash
```

## Manual deploy. Create the stack in AWS (Terminal 1)

https://us-east-1.console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:instanceState=running

```
terraform init && terraform apply
```

## Optional: ECR for the Docker lab

From this directory, create the repository and display its URL:

```bash
terraform apply -var="ecr=true"
terraform output -raw ecr_repository_url
terraform output -raw ecr_login_cmd
terraform output -raw ecr_export_cmds
terraform output -raw ssh_cmd
```

Connect to the instance and run the `ecr_export_cmds` and `ecr_login_cmd` outputs there to configure the lab and authenticate Docker using its existing `LabInstanceProfile`.

Run login and Docker commands as the same user. The login token expires after 12 hours. Follow the [ECR lab](../../containers/labs/02-Docker/02.6-ECR/README.md) to build, push and pull an image.

Keep `-var="ecr=true"` for subsequent plans and applies while using the repository. **`terraform destroy -var="ecr=true"` permanently deletes the repository and all of its images.**
