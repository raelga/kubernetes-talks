# Notes

## AutoDeploy using AWS Academy Learner Lab or CloudShell console

```bash
curl -sqL http://go.rael.dev/k8s-academy-ec2-llab-start | bash
```

## Manual deploy. Create the stack in AWS (Terminal 1)

https://us-east-1.console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:instanceState=running

```
terraform init && terraform apply --var "github_user=YOUR_GH_USER_ID"
```
