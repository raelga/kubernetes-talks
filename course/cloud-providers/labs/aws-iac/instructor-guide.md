# AWS lab guide

Deploy a small HTTP server, understand its network and private storage, make a change, then remove everything. Follow the [README](README.md) for the full command sequence.

## Before starting

- Confirm your AWS account, region, credentials, quotas and permissions. Use an allowed AMI and instance type.
- Check the [Terraform requirements](versions.tf) and the README's tool prerequisites.
- Use your own working directory, local state and unique `lab_id`. Do not copy another deployment's state or adopt existing resources.
- Set `client_cidr` to your public IPv4 `/32`. Check that the VM can reach the package repositories.
- Keep credentials, state, plans and real outputs out of Git. Identify any shared resources that must stay untouched.

## Understand what you are creating

| Component | Purpose |
| --- | --- |
| VPC, subnet, Internet Gateway and route | Connect the VM to the Internet |
| Security group | Allow HTTP only from your client IP; no SSH |
| EC2 and encrypted root disk | Run the HTTP service |
| Private S3 bucket | Separate object storage; the VM does not use it |

The VM has no IAM role or cloud credentials. An Internet route is not an open ingress rule. HTTP is plaintext, and base64 user-data is not encryption: use no secrets in the demo content.

## 1. Review the plan

Follow the README's configuration and planning steps. Check:

- Correct account, region, ownership tags and client `/32`.
- Only this lab's resources; no IAM changes, SSH or unrelated infrastructure.
- Expected instance, disk, public-IP and storage costs.

`validate` checks configuration, not permissions or affordability. If inputs change, generate and review a new plan before applying it.

## 2. Deploy and open the service

Apply the reviewed plan and save `outputs.local.json`. Find the tagged EC2 instance, subnet, route and security group in the AWS console.

Open the printed HTTP URL or run:

```sh
curl --noproxy '*' --fail "$(terraform output -raw http_url)"
```

Expect a successful JSON response containing your message and `status: "ok"`. **EC2 running does not mean the application is ready.** Check cloud-init in the instance system log if needed. The S3 bucket must remain private and empty.

## 3. Verify the deployment

From the lab directory, use the saved outputs and your actual lab ID and region:

```sh
python3 inventory.py --live --outputs outputs.local.json --lab-id YOUR-LAB-ID --region YOUR-REGION --probe-http
```

The verifier is read-only. It checks account, region, ownership tags, resource IDs, networking, encrypted disk, S3 protections and the HTTP response. An API error must fail; it is not an empty inventory or a reason to fall back to fixtures.

For offline exploration, `--fixture-dir fixtures` uses explicitly synthetic data. It does not verify AWS or the web service.

## 4. Change the message

Follow the README change flow: edit `message`, review the plan and apply it.

This **replaces EC2 and its root disk**, rather than updating a running app. Save fresh outputs, open the new URL and confirm the new message. A subsequent plan should show no changes.

Optional network experiment: change only your deployment's client CIDR to `192.0.2.10/32` through a reviewed plan. HTTP should fail. Restore your actual `/32` through another reviewed plan and verify recovery. Never widen access to `/0`.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Expired credentials / AccessDenied | Renew credentials for the same account. Stop if permissions are missing; do not weaken IAM or account policies. |
| EC2 running, HTTP unavailable | Instance system log/cloud-init, client public IP, route and security group. |
| Inventory succeeds, HTTP fails | Service readiness and `/32`; refresh outputs after replacement. |
| BucketNotEmpty | Review objects in that exact bucket with its owner. No recursive emptying or `force_destroy`. |

Fix the cause rather than hiding errors or adding SSH/IAM access.

## Check costs

Use Billing and Cost Explorer to inspect compute, disks, public IPv4, S3 and traffic. Filter by date, service, region and existing ownership tags; do not change account-wide settings for the lab.

Billing data and tags can be delayed. Small instances are not necessarily free, stopping EC2 does not remove its disk, and budget alerts do not automatically stop spending. Do not create budgets or notifications without authorization.

## 5. Clean up and confirm

Follow the README cleanup steps using the original directory, workspace and state.

1. Save **current outputs before destroy**, including replacement IDs and IPs.
2. Review the destruction plan: only this lab's resources, never shared infrastructure.
3. Apply it, run the absence verifier and confirm empty state.
4. Verify disks, networking and the exact bucket are gone. Terminated EC2 is acceptable; only `NoSuchBucket` establishes S3 absence.

API failures and empty state alone do not prove cleanup. Retain private state until absence is verified. After partial failure, clean up from the same state—never delete state to conceal resources or bulk-empty storage. If anything remains, record the resource, owner and next action.
