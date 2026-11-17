# 02.4 · Push and pull an image with Amazon ECR

Build a Docker image, publish it to a private Amazon Elastic Container Registry (ECR) repository, and pull it back.

## Before you start

- Deploy the [Academy EC2 instance](../../../../terraform/aws-academy-ec2-instance/README.md) with `terraform apply -var="ecr=true"`. This creates the repository; the instance already uses `LabInstanceProfile`.
- On the machine where you ran Terraform, get the repository URL:

  ```bash
  terraform output -raw ecr_repository_url
  ```

- Connect to the instance using `terraform output -raw ssh_cmd`. Run the remaining commands **on the instance**. Docker must be running, and your user must be in the `docker` group.

## 1. Select your repository

Copy the URL from the Terraform output and replace the example below:

```bash
export REPOSITORY="ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/REPOSITORY_NAME"
export REGISTRY="${REPOSITORY%%/*}"
```

## 2. Authenticate Docker

```bash
aws ecr get-login-password --region us-east-1 |
  docker login --username AWS --password-stdin "$REGISTRY"
```

Docker uses the instance profile's temporary credentials. If you have configured AWS credentials or environment variables on the instance, they can take precedence over the profile. The Docker login expires after 12 hours; repeat it if needed. Use the same user for login and Docker commands.

## 3. Build and push

From the repository checkout on the instance:

```bash
cd ~/kubernetes-talks/course/containers/labs/02-Docker/02.2-hello-world-go
docker build -t "$REPOSITORY:v1" v1
docker push "$REPOSITORY:v1"
```

The full image name identifies both the registry and the repository. Unqualified image names still use Docker's default registry.

## 4. Pull and run

```bash
docker image rm "$REPOSITORY:v1"
docker pull "$REPOSITORY:v1"
docker run --rm -d --name ecr-hello -p 9999:9999 "$REPOSITORY:v1"
curl http://localhost:9999/
curl http://localhost:9999/health
docker stop ecr-hello
```

You should see `Hello World` and `OK`. Removing the local tag forces Docker to fetch the image metadata again; cached layers may still be reused.

## Clean up

From the Terraform directory on the machine where you deployed the instance:

```bash
terraform plan -destroy -var="ecr=true"
terraform destroy -var="ecr=true"
```

**This permanently deletes the repository and all images in it**, including images pushed outside Terraform. Keep `-var="ecr=true"` for plans and applies while using the repository. Registry storage and the instance can incur charges.
