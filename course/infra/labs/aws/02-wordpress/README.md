# WordPress: from one VM to replaceable instances

Follow the stages in order. Stages 02.4–02.7 share one VPC and RDS instance; keep those foundations until the later stages are finished, then destroy application stacks before shared infrastructure. Use disposable data and approved AWS Academy credentials. Do not commit Terraform state or secrets.

1. [WordPress and MySQL on EC2](02.1-local-mysql/README.md): observe loss of database and files when the instance is replaced.
2. [Move MySQL to RDS](02.2-rds/README.md): EC2 and RDS share one Terraform state; the database survives replacement.
3. [Introduce modules](02.3-modules/README.md): reuse the network, MySQL and EC2 configurations.
4. [Multiple Terraform stacks](02.4-multi-stack/README.md): reuse the modules in separate network, shared RDS and application states; later stages use their own application databases.
5. [Replace EC2 with an Auto Scaling group](02.5-asg/README.md): a manual WordPress update disappears when a replacement is launched.
6. [Build versioned AMIs](02.6-ami/README.md): use Packer to build and roll out pinned WordPress versions.
7. [Move uploads to S3](02.7-s3/README.md): test whether media and database content survive replacement.

## Before you start

- Complete [Terraform state in S3](../00-terraform-state/README.md) and use your AWS Academy credentials.
- These labs expose HTTP publicly, including deliberately old WordPress releases. Use disposable passwords and synthetic data; never use real credentials.
- EC2, RDS, load balancers and storage can incur charges. Free Tier eligibility depends on your account and allowance.
- Terraform state can contain credentials. Keep it private and never commit it.

Before **02.1**, from this directory, load the state bucket created in lab 00:

```sh
export TF_VAR_state_bucket="$(terraform -chdir=../00-terraform-state/remote output -raw state_bucket_name)"
echo "$TF_VAR_state_bucket"
```

Confirm the bucket name is displayed. Keep the same terminal for the remaining stages; if you open a new terminal, run these commands again. Each learner uses a dedicated bucket. Stages 02.6 and 02.7 share their application state; other stacks use separate paths.

If you deployed an earlier version using local state or different state keys, clean it up or migrate its state before using these paths. Changing the backend does not move or destroy existing resources.

## Terraform dependency graph

The architecture diagrams show the infrastructure; `terraform graph` shows Terraform's dependency relationships.

1. Install [Graphviz](https://graphviz.org/download/) (`brew install graphviz` on macOS; on Windows, install Graphviz and add `dot` to your PATH).
2. From a lab directory initialized with the correct AWS credentials and backend, generate the PNG:

   ```sh
   mkdir -p assets
   terraform graph | dot -Tpng -o assets/terraform-graph.png
   ```

For 02.4, run this in `network/`, `database/` or `wordpress/`: each is a separate Terraform root and has its own graph. The command does not deploy infrastructure. Inspect generated graphs before sharing; resource identifiers may reveal infrastructure details.
