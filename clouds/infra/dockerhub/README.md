# Shared public Docker Hub repository

This Terraform root declares public `raelga/clouds-guestbook` using `docker/docker` provider `~> 0.7.0`. It is a shared preparation resource, **not** a per-session cluster resource. Retain the repository, published image and this root's independent local state during cluster teardown.

Use [RUNBOOK.md](../../RUNBOOK.md) for demonstration execution and [detailed preparation](../../RUNBOOK-DETAILED.md#isolated-personal-docker-hub-configuration) for isolated personal `DOCKER_CONFIG`, the separate Docker daemon selection and publication commands. Run commands from the project root. Never use work/Red Hat tools or credentials for this personal lab.

## Credentials and state

Use the intended personal Docker Hub login under an isolated `DOCKER_CONFIG`, or privately exported `DOCKER_USERNAME` / `DOCKER_PASSWORD` for the Terraform provider. Never commit credentials or use a different account's configuration accidentally. The provider manages repository configuration; Docker/buildx publishes images. Kubernetes pulls the public image anonymously, without image-pull Secrets, AWS credentials or ECR.

The existing repository is already imported/tracked. Use its original state; **do not repeat import or create a replacement state**. For a different, newly adopted repository only, import before planning if it already exists externally:

```bash
terraform -chdir=infra/dockerhub init -input=false -lockfile=readonly
terraform -chdir=infra/dockerhub import docker_hub_repository.guestbook raelga/clouds-guestbook
```

That import command documents first adoption, not routine execution. A separately approved new repository can be created through a reviewed Terraform plan with the intended `namespace` input. Current namespace defaults to `raelga`. Preserve lockfiles and private state/backups/plans.

For a deliberate repository configuration change, initialize and review:

```bash
cd infra/dockerhub
terraform init -lockfile=readonly
terraform plan
```

Only apply intended changes after required approval; ask before billing changes or deletion:

```bash
terraform apply
cd ../..
```

## Shared image contract

Both modes and all providers use `docker.io/raelga/clouds-guestbook:demo-v3`, pinned in `k8s/base/kustomization.yaml`. This release includes the AWS Sydney map marker. Do not rebuild it to run the demo. For changed code, publish a new tag for `linux/amd64` and `linux/arm64`, then update the base's `newTag` and `digest`. No provider-specific image is needed.

Anonymous Docker Hub [pull limits](https://docs.docker.com/docker-hub/usage/pulls/) apply; an image-pull failure does not authorize a paid upgrade. The [historical registry cutover](../../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21) verified anonymous manifest access/pull and retained Local/Shared messages across all eight application rollouts. The obsolete ECR repository was subsequently removed after explicit approval. Do not recreate it.

## Retention

The [approved full cleanup sequence](../../RUNBOOK-DETAILED.md#cleanup) intentionally excludes this root. Do not destroy the shared registry/image when deleting per-session clusters, routing or D1. Any future repository or image deletion needs separate explicit approval and review of downstream consumers. Keep its state after cluster cleanup.
