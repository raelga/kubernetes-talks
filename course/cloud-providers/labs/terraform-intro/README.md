# Your first Terraform lab: buckets and state

Learn how Terraform creates infrastructure, applies changes and tracks resources. In about **90 minutes**, you will create two private S3 buckets, upload a file and move your Terraform state to S3. No VMs, Kubernetes or IAM changes.

| Directory | What it creates | Where its state lives |
| --- | --- | --- |
| `bootstrap/` | The bucket that will store Terraform state | Always local; keep a secure backup |
| `exercise/` | A separate bucket and `hello.txt` | Local first, then S3 |

**Configuration describes what you want. State records what Terraform manages.** Keep each learner's state separate; copying someone else's state means managing their resources, not creating your own.

## Get ready

Run this in your Academy terminal to install Terraform 1.13.3 and clone the repo:

```bash
curl -fsSL https://raw.githubusercontent.com/raelga/kubernetes-talks/main/course/cloud-providers/labs/terraform-intro/bootstrap.sh | bash
```

It installs Terraform in `$HOME/.local/bin` and clones `main` into `$HOME/kubernetes-talks`. Existing checkouts are left untouched. It does not change directory, configure AWS or deploy anything. Requires Git, curl, unzip and a SHA-256 utility.

Now open the lab and check your tools and Academy identity:

```bash
cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro"
terraform version
aws --version
aws sts get-caller-identity
```

Use Terraform **>= 1.10 and < 2.0**, AWS CLI v2 and your assigned temporary credentials. Confirm the account, allowed region, session expiry, persistence and budget with your instructor. Never put credentials in Terraform files or Git.

The instructor must check Cloud Control/S3 permissions, including state and lock access, before the lab. An identity check alone does not prove those permissions. **Stop on access errors; do not weaken protections or change IAM.** See the [instructor guide](instructor-guide.md) for preflight details and prior Academy verification.

S3 storage, versions and requests can cost money. Billing is delayed; budget alerts do not automatically stop spending.

## 1. Create backend infrastructure, but keep its state local

Start in the directory that creates the state bucket:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: enter your account, authorized region and a recognizable `lab_id`. Keep `bucket_name = null`, `enable_versioning = false` and `stage = "basics"`.

Bucket names include a random suffix saved in state, so independent runs do not collide. An optional `bucket_name` uses an exact, globally available name instead; it must differ from the other bucket and does not import existing storage. Changing names/account/lab ID can require replacement. Do not delete state or remove the backend's `prevent_destroy` protection to work around it.

```bash
terraform init
terraform fmt
terraform validate
terraform plan -out=private-bootstrap.tfplan
terraform apply private-bootstrap.tfplan
terraform output
```

**Read the plan before applying.** Confirm the account, region and private, encrypted bucket. `init` installs providers; `validate` checks configuration, not permissions or costs; `plan` previews changes; `apply` executes the saved plan. Editing configuration afterward requires a new plan.

Keep this directory and its local state securely backed up outside Git and the bucket. **Never migrate bootstrap's own state into its bucket.**

Next, set `enable_versioning = true` and `stage = "backend-ready"` in the same tfvars file:

```bash
terraform plan -out=private-versioning.tfplan
terraform apply private-versioning.tfplan
export AWS_REGION="us-east-1" # Use the authorized region from your tfvars.
export STATE_BUCKET="$(terraform output -raw state_bucket_name)"
aws s3api get-bucket-versioning --bucket "$STATE_BUCKET" --region "$AWS_REGION"
```

Require `"Status": "Enabled"`. Wait **15 minutes after first enabling versioning before writing to this bucket**. Work through the exercise below while it propagates.

## 2. Apply the exercise with local state

Switch to the separate exercise directory:

```bash
cd ../exercise
cp terraform.tfvars.example terraform.tfvars
```

Set the same account, region and `lab_id`, with `demo_tag = "initial"`. **Do not enable the S3 backend yet.**

```bash
terraform init
terraform validate
terraform plan -out=private-exercise.tfplan
terraform apply private-exercise.tfplan
export EXERCISE_BUCKET="$(terraform output -raw exercise_bucket_name)"
aws s3api get-object --bucket "$EXERCISE_BUCKET" --key hello.txt --region "$AWS_REGION" private-hello.download.txt
```

Read `private-hello.download.txt`. The object is private: download it with your credentials, not an anonymous URL. Use only nonsensitive example content.

**Stay in `exercise/` for the remaining steps.**

## 3. Changes and drift, only in the exercise

1. Edit `../files/hello.txt` and set `demo_tag = "updated"` in `terraform.tfvars`.
2. Run `terraform plan -out=private-change.tfplan`. Review the changes, then run `terraform apply private-change.tfplan`. Download `hello.txt` again to see the new content.
3. In the S3 console, open exactly `$EXERCISE_BUCKET` and change only its `Demonstration` tag to `outside-terraform`. Keep all other tags; **do not touch the state bucket**.
4. Run `terraform plan -out=private-drift.tfplan`. It should restore the declared tag without replacing the bucket. Review and apply with `terraform apply private-drift.tfplan`.

That difference between code and the actual resource is **drift**. Do not hide it with `ignore_changes`.

## 4. Migrate only the exercise state

Before continuing, ask the instructor to confirm versioning propagation and state/lock permissions. Nobody else should be using this state.

Save the current resource IDs and a private state backup, then enable the backend:

```bash
terraform output -json > private-ids.before.json
terraform state list
terraform state pull > private-before-migration.tfstate
cp backend.tf.example backend.tf
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` with the actual `$STATE_BUCKET`, account and region. Keep `key = "exercise/terraform.tfstate"`, `encrypt = true` and `use_lockfile = true`. Backend settings are separate from tfvars; never add credentials.

```bash
terraform init -migrate-state -backend-config=backend.hcl
terraform output -json > private-ids.after.json
diff private-ids.before.json private-ids.after.json
terraform plan
aws s3api head-object --bucket "$STATE_BUCKET" --key exercise/terraform.tfstate --region "$AWS_REGION"
```

Accept the migration prompt only for the intended source and destination. Do not use `-reconfigure` or force copying. Expect unchanged IDs, a **no-change plan**, and an S3 state object with `AES256` encryption and a `VersionId`. Migration moves the record; it does not recreate infrastructure.

### Observe the lock without writing resource changes

Set `demo_tag = "lock-observation"` temporarily and run `terraform apply`. **Leave the approval prompt open; do not approve.**

In a second terminal with the same authorized credentials:

```bash
cd "$HOME/kubernetes-talks/course/cloud-providers/labs/terraform-intro/exercise"
terraform plan -lock-timeout=5s
```

The second operation should fail because the first holds the state lock. Answer **`no`** in the first terminal, restore `demo_tag = "updated"` and run `terraform plan`: no changes. Never delete an active lock or force-unlock another operation.

The S3 `.tflock` object protects state operations. `.terraform.lock.hcl` pins provider versions and checksums; it is not a concurrency lock. No DynamoDB is needed here.

## 5. Normal completion: remove only the exercise

Still in `exercise/`, prepare and inspect a destruction plan:

```bash
terraform plan -destroy -out=private-destroy.tfplan
terraform show private-destroy.tfplan
```

Confirm it removes only the exact exercise bucket, `hello.txt` and its random suffix—**never the backend bucket**. Then:

```bash
terraform apply private-destroy.tfplan
terraform state list
```

Expect no managed exercise resources. Confirm the exact exercise bucket is gone in AWS; an empty state alone is not proof. A normal plan now proposes recreation: do not apply it. If deletion fails because the bucket contains extra objects, review those objects with the instructor; do not bulk-empty it.

**Keep the backend bucket and bootstrap's local state.** Even an empty remote state still depends on the backend. Full backend retirement is a separate authorized procedure in the [instructor guide](instructor-guide.md#complete-and-exceptional-backend-retirement), not part of normal cleanup.

Keep credentials, states, plans, private tfvars, backend settings and real captures out of Git and securely stored. Reviewed `.terraform.lock.hcl` files can be committed.
