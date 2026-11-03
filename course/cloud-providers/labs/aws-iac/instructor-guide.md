# Instructor guide · 02 AWS: fundamentals and provisioning as code

**05/11/2026 · 18:00–21:00 · Rael Garcia · 3 h.** M2 with **1 transversal hour of M1** covering Python and AI-assisted review, included in these three hours, not additional. Entry profile: junior learners with basic Linux, networking and scripting. AWS is the main student hands-on lab; session 3 transfers this pattern to Azure/GCP demonstrations, not two mandatory new accounts/deployments.

The material contains an executable implementation and **synthetic** responses for practice without credentials. **The complete network/EC2/HTTP lab has not been tested against AWS.** Available live evidence is an isolated S3 trial with the same Academy role: `hashicorp/awscc` 1.108.0 created a private/encrypted bucket with enforced ownership, refreshed it with a no-change plan and destroyed it. Do not extend that evidence to a complete execution of the introductory lab or this VM lab. A successful offline run does not establish actual Academy, apt, EC2 or Billing availability either.

## Learning outcome and teaching scope

By the end, learners can interpret HCL dependencies and a plan, deploy a small HTTP VM and private bucket, query their own resources with Python/CLI, justify a change/reconciliation, identify costs and verify controlled destruction. Designing a landing zone or learning boto3 from scratch is not assessed.

Scenario: dedicated VPC/subnet/IGW/table/route/association, HTTP SG restricted to `/32`, Ubuntu 24.04 x86_64 EC2 and empty private S3 with AES256 encryption and enforced ownership. The Python application uses the standard library, without Docker. Its process runs as an unprivileged system user with a limited capability to bind port 80. The VM has no credentials, IAM role, key pair or assigned S3 access. The client uses existing Academy permissions; do not create users, roles, policies or instance profiles.

Also present identity, image registry (ECR), databases and managed services as a map of equivalents/needs. Do not add ECR/EKS/RDS, a load balancer, NAT Gateway or extra deployments to this exercise. Do not turn extensions into project requirements.

## Required preflight before class

### Confirm the specific Academy environment (do not infer from the brand)

Record for the group, without secrets:

- Actual lab name/type and assigned official instructions. Invitation/access from session 1; startup procedure, duration, session and credential renewal, persistence between sessions and the exact meaning of Start/End/Stop/Reset.
- Authorized account and region, allowed x86_64 types and EC2/VPC/EBS/S3 quotas. The example offers `t2.micro`, `t3.micro`, `t3.small`, `t3a.micro`, `t3a.small`: select **one that is actually permitted**, rather than assuming t3.micro exists or is free. If only another type is available, agree on adapting the validation list before class while retaining a small size, without bypassing restrictions.
- `DescribeImages` lookup for Canonical's official Ubuntu 24.04 amd64 (`099720109477`) and launch permission. If lookup is disallowed, provide an authorized Ubuntu 24.04 x86_64 `ami_id` in the region. A syntactically valid ID may belong to another region, be arm64 or require marketplace permission: HCL validation does not resolve this.
- Existing permissions to create/tag/describe/delete VPC, subnet, IGW, route table/route/association, SG, EC2 and encrypted EBS; IMDSv2 metadata configuration; S3 create/tag/BPA/encryption/ownership and empty-bucket destruction. Confirm EBS encryption with the service key is permitted, without adding IAM/KMS changes. Verifier read-only actions include STS identity, EC2 Describe and S3 GetBucketTagging/GetPublicAccessBlock/GetBucketEncryption/GetBucketOwnershipControls. `GetBucketTagging` must return NoSuchBucket for a deleted bucket belonging to the exercise; AccessDenied is not evidence of absence.
- `awscc_s3_bucket.private` uses AWS Cloud Control API: check permissions to create/read/update/delete resources and query operation status, in addition to underlying S3 actions and direct inventory queries. The official `hashicorp/awscc` 1.108.0 provider completed the isolated S3 trial with the same Academy role, without adding IAM or modifying SCP. The previous `hashicorp/aws` 5.100.0 alternative, managing `aws_s3_bucket`, attempted to read `s3:GetBucketObjectLockConfiguration` even without Object Lock enabled and encountered an explicit SCP deny after creating the bucket; that partial resource was cleaned up. The supported Cloud Control path retains complete public blocking, AES256, enforced ownership and tags without weakening policy. Verify the specific environment and authorized lifecycle before class: the isolated trial does not demonstrate EC2/network permissions or complete lab functionality.
- Temporary authentication compatible with CLI/providers and sufficient validity through destroy. Identity used for `apply` and the subsequent query must match. Do not assume the browser automatically supplies credentials to the terminal.
- Ubuntu has outbound DNS/HTTP/HTTPS access to its repositories and cloud-init/systemd. The AMI does not install Docker; apt can fail due to connectivity or unavailability. `running` does not imply successful bootstrap.
- Learners can reach the EC2 public IP on port 80 from their outbound IPv4. VPN, NAT and corporate policies can change/block that IP. Do not open `/0` or port 22 to make practice easier.
- Billing, Cost Explorer and Budgets: which views the role permits; an authorized instructor account or prepared synthetic sample if unavailable. Do not promise enabled cost allocation tags or instantly visible spending.

No “universal Academy” IAM policy is prescribed: verify actual restrictions and explicitly adapt the activity. A denial is not solved with borrowed administrator credentials or privileged Python calls.

### Tools and state

Terraform `>=1.6,<2`, `hashicorp/aws` `>=5.80,<6` for identity/EC2/network, `hashicorp/awscc` `>=1.108,<2` for S3, `hashicorp/random` `>=3.6,<4` for the suffix, Python `>=3.11`, AWS CLI v2. Both AWS providers use `var.aws_region` and existing temporary credentials. Verify Python executable resolution (some macOS system versions are 3.9), provider downloads and network access. There is no dependency on boto3, pip or a heavyweight SDK. Start the app locally with `python3 app.py --host 127.0.0.1 --port 8080`; neither root nor AWS is required.

Each learner uses a private working copy, local state and a distinct `lab_id`. Do not reuse the instructor directory/state or a shared backend. Generated bucket names use account+lab_id+a random 12-hexadecimal-character suffix persisted in state; new state generates another suffix but does not change the requirement for an individual lab_id for network/VM resources. `bucket_name` accepts an exact globally available name without a suffix (null by default), not adoption of existing storage; changing it can trigger replacement. Consume the actual name from outputs. Explain that separate directories are insufficient if someone else's state is accidentally copied. Confirm directory/workspace before plan/apply/destroy and review the exact change list.

Retain the resolved provider lockfile for reproducibility. Do not distribute real state, saved plans, credentials or outputs describing personal infrastructure; the only included captures are JSON explicitly marked synthetic. Agree on a local location for sanitized evidence.

### Preserve the container environment (sessions 4–5)

This exercise **is not** preparation of the Academy runtime for sessions 4 and 5. The cloud-02 VM must be destroyed; do not install Docker on it as a shortcut or make it a later dependency. Before session 4, separately verify the permitted OCI-compatible runtime, CLI/Compose, registry, connectivity, ports, quotas and persistence in the actual assigned environment. If that environment shares an account with cloud-02, explicitly identify its resources and exclude them from this state and destruction plan.

Show the difference between removing this directory's Terraform resources and Academy portal actions. Do not request Reset, a general End Lab or destruction of shared resources. Explain how each learner ends their session according to lab instructions without losing the prepared runtime.

## 180-minute teaching sequence

| Time Europe/Madrid | Min | Activity and evidence |
|---|---:|---|
| 18:00–18:15 | 15 | Access/identity/region, scope, temporary credentials and Academy budget. AWS map: compute, networking, storage, IAM, ECR and managed services; no extra deployments. |
| 18:15–18:40 | 25 | Read HCL/dependencies, AWS default tags and explicit AWSCC tags, AMI/type, `/32`, S3 through Cloud Control and user-data. Configure individual variables, init/validate, read plan and local state. |
| 18:40–19:05 | 25 | Apply reviewed plan, save JSON outputs, explain EC2 running versus bootstrap. Guided diagnosis without SSH. |
| 19:05–19:20 | 15 | **M1**: run offline parser, explore nested JSON and shell-free subprocess arguments. |
| 19:20–19:45 | 25 | **M1**: copy fixtures, inject stopped/missing instance/public S3, review a small AI proposal while preserving failures and filters. |
| 19:45–20:05 | 20 | **M1**: separate live queries from offline analysis; tag/output inventory and optional HTTP probe. Compare IDs, message and errors. **Total M1 60 min.** |
| 20:05–20:25 | 20 | Change message, interpret user-data replacement and save new outputs. Documentation `/32` failure, group diagnosis and restoration. If bootstrap consumes time, instructor demonstrates injection without omitting cause/recovery explanations. |
| 20:25–20:45 | 20 | **AWS costs**: Bills, Cost Explorer, filters, Budgets/alerts and limits; explicit sample if permissions/delays prevent live queries. |
| 20:45–21:00 | 15 | Save current outputs, destroy plan/review/application, read-only `--expect absent` query and empty state. Record outstanding work without falsely declaring cleanup. |

Preserve the 60 M1 minutes and 20 cost minutes. Start from the prepared implementation rather than spending class writing HCL from scratch. Do not consume wrap-up time with unplanned installations or extensions. If permissions prevent a learner deployment, separate offline analysis from the instructor's authorized demonstration and honestly record the missing live evidence rather than simulating success.

## Security and Python walkthrough

Before `apply`, ask: “What enters through the SG? Why is a 0/0 route not a 0/0 SG? Who reads S3? Where are the credentials?” Then show that base64 in user-data only avoids escaping problems and does not protect secrets. The server serves only two JSON routes and does not expose a file directory.

Inventory requires either `--live` or `--fixture-dir`; it never implicitly tries AWS or falls back to fixtures after failure. Live mode requires saved outputs, `--lab-id` and `--region`, compares the STS account, queries seven EC2 families using three tags and queries one exact bucket. It does not call create/update/delete/stop/start or execute a shell. Permission, JSON, timeout or dead/missing expected-resource errors produce nonzero exits; only `NoSuchBucket` establishes bucket absence. In present mode IDs must match exactly, including the absence of extra resources with the same tags.

The HTTP probe must be explicitly requested and is only available in live/present mode. It does not follow redirects or use proxies and checks the scenario JSON. Offline rejects `--probe-http`: documentation addresses are never used to simulate a live response. Without the probe option, a successful API query does not establish application health. Ownership checks rely on tags and outputs; this is not a whole-account auditor or an IAM authorization boundary.

AI exercise: supply only the fixture, request explanation/a small output adaptation and review failure cases, rather than generating a cloud controller. Reject proposals that add `shell=True`, ignore CLI return codes, catch everything to print “OK”, remove filters, follow arbitrary URLs or request secrets. Evidence is reasoning and comparison, not prompt length.

## Cost demonstration (20 minutes, not a generic warning)

1. Open **Billing and Cost Management → Bills**, select month/account and distinguish EC2 compute from EBS/EC2-Other, public IPv4, S3 and traffic. Record each item's unit; “micro” does not mean free and stopping EC2 does not clean up EBS.
2. Open **Cost Explorer → Cost and usage**. Show dates, daily granularity, group by service and filter by region; then show available cost allocation tags. Explain why an inactive tag or untagged charge may not appear in a filter. Do not enable global billing tags as an exercise side effect.
3. In **Budgets → Create budget → Cost budget**, show a teaching monthly budget (e.g. USD 5), scope and actual-spend thresholds of 50/80/100%, forecast 100%. Review the recipient with its owner and confirmation if required by the selected notification. Use an authorized instructor account or walk through the form without saving when alerts must not be created. Do not execute budget actions or send test emails to unauthorized people.
4. Explain billing/alert delays and that a budget does not automatically stop spending. Distinguish this mechanism from the actual Academy indicator and its specific rules, without guaranteeing a universal stop.
5. If permissions or recent data are unavailable, use the README's **synthetic** table. It is invented, not a capture or rate: group USD 0.06 and make the untagged row's effect visible. State what was actually observable and what was not. The activity remains interpretation of queries, filters and alerts, not production of a fictional learner invoice.

At wrap-up, connect costs to `root_volume_id`, public IP and `delete_on_termination`. Future managed-cluster sessions revisit control planes, nodes, load balancers, disks and traffic; do not add them here.

## Wrap-up, incidents and acceptance

Use the exact README cleanup block: **current** outputs before destroy, reviewed destruction plan, application and query with `--expect absent`. Expect instances to remain listed as terminated; check that the tagged disk and network disappear. If AccessDenied prevents querying S3 after deletion, record “no evidence due to permissions”, not “deleted”. Manage persistence/credentials according to the specific Academy environment to complete verification.

The bucket starts empty and [`awscc_s3_bucket`](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/s3_bucket) only permits deleting it when empty; its schema includes neither `force_destroy` nor automatic emptying. For BucketNotEmpty, review the exact bucket and agree on explicit deletion only of its data; do not introduce a recursive script. After partial apply failure, retain state, plan from the same state and clean up what was created; never delete the file to hide failure. Renew expired tokens through the official procedure and in the same account. Diagnose apt errors without adding SSH or IAM permissions and without confusing the offline parser with a repair.

Accept sanitized evidence of plan/change, offline/live separation, intentional failure and AI review, cost/alert design and cleanup verification. Do not request real state or plans in submissions. Record every pending resource with an owner and specific cause without declaring cleanup complete. This session does not change course grading weights or create advanced final-project requirements.
