# Cloudflare Worker routing and shared D1 state

Use [RUNBOOK.md](../../RUNBOOK.md) for the Local datastore → isolation → Shared datastore execution sequence. Use the [detailed reference](../../RUNBOOK-DETAILED.md#preparation) for individually explained credential setup, required inputs, [fresh-only bootstrap](../../RUNBOOK-DETAILED.md#fresh-only-workerd1-bootstrap), [origin precedence](../../RUNBOOK-DETAILED.md#real-origins-and-input-precedence) and [approved cleanup](../../RUNBOOK-DETAILED.md#cleanup). Run commands from the project root.

Terraform in `infra/cloudflare` owns Worker `clouds-global-router`, D1, `guestbook.rael.dev` custom domain and DNS-only aliases in existing `rael.dev`. It does not register domains, change nameservers, buy managed Load Balancing or upgrade plans. Worker source and local Wrangler workspace are in `app/router`; Wrangler deploy must not become a second cloud owner.

## Prerequisite: one token for DNS and runtime

Create one custom Cloudflare API token, restricted to the intended account and `rael.dev`, with:

| Scope | Required permissions |
|---|---|
| Account | Workers Scripts: Edit; D1: Edit |
| Zone `rael.dev` | Zone: Read; DNS: Edit; Workers Routes: Edit |

The single Terraform provider uses `CLOUDFLARE_API_TOKEN` for DNS, Workers, custom domains and D1. Wrangler OAuth and a separate DNS-token variable are not required. Successful read requests do not prove edit permissions; our existing token's read access was verified, but its edit policies could not be inspected.

Load and export the combined token privately as `CLOUDFLARE_API_TOKEN`; the provider reads it directly. From the project root, set the account:

```bash
export TF_VAR_account_id="${CLOUDFLARE_ACCOUNT_ID:?Load your Cloudflare account ID privately}"
```

Keep the existing ignored `k8s/shared/credentials.env`. Terraform and Kustomize read its separate `STATE_API_TOKEN` directly. Do not put the management token in that file or rotate the application token. No application-token export or Terraform input is needed.

The detailed reference separates new-installation-only token generation from existing-token reuse. Terraform's sensitive marking redacts output; state/backups/plans still contain secrets. Preserve them privately. The app token is never browser JavaScript or a Cloudflare management token. Keep original state and the matching generator input throughout operation and deletion rendering.

## Bootstrap and real origins

This root supports fresh deployment with empty origins: `/state/*` works before Services exist while frontend routing returns 503. D1's message table is created idempotently on first authenticated use; preserve database identity and data when adding origins. Terraform only creates resources when you approve an apply; no paid-plan upgrade is included.

Both variants reuse the `guestbook` Deployment/Service in `k8s/base`, with `app=guestbook` selectors. `k8s/shared` adds `guestbook-shared-location` with `APP_MODE=shared` and `STATE_API_URL=https://guestbook.rael.dev`; the app appends `/state/messages` and verifies TLS. The `guestbook-shared-state` Secret generator reads ignored `k8s/shared/credentials.env`. Terminal exports do not override YAML. Browser requests use same-origin `/api/messages`; only app backends send the bearer token to Worker/D1.

For a future approved fresh run, configure Cloudflare once with the four `guestbook` Service addresses after Local datastore is ready. Shared datastore rolls the same Deployment behind the same Services: do not change origins again. Old and new modes may briefly coexist; wait for rollout completion and all desired replicas Ready before demonstrating. Switching does not migrate messages. Fresh clusters require no legacy app migration.

Maintain ignored `infra/cloudflare/origins.auto.tfvars` with keys **exactly** `aws`, `azure`, `gcp`, `digitalocean`. Empty string values are ignored. With no configured origins, frontend requests return 503 while the authenticated state API remains available. See [origin configuration](../../RUNBOOK-DETAILED.md#real-origins-and-input-precedence). Auto tfvars override environment variables; explicit variable flags override auto files.

```bash
cd infra/cloudflare
terraform init -lockfile=readonly
terraform plan
```

Review the intended account/zone/hostname, D1 creation, reused private application token and real configured origins before applying. Historical D1 data is not restored merely by recreating the database:

```bash
terraform apply
cd ../..
```

Interactive apply presents a fresh plan for confirmation. IP origins receive Terraform-managed address-hashed DNS-only A/AAAA aliases: direct Worker IP fetches previously returned 403/error 1003. Existing AWS ELB hostnames are used directly. Do not modify unrelated DNS records. Inspect actual Worker targets if necessary:

```bash
terraform -chdir=infra/cloudflare output origin_hostnames
```

## Routing and data semantics

New sessions use trusted `request.cf.continent`: Americas (`NA`/`SA`) → DigitalOcean (`nyc1`, New York), Europe/Africa (`EU`/`AF`) → Azure (`westeurope`), Asia (`AS`) → GCP (`asia-northeast1-a`), Oceania (`OC`) → AWS (`ap-southeast-2`, Sydney). Unknown geography is random; an existing valid `clouds_origin` cookie wins. Clear it to test visitor-continent selection. This is HTTP edge selection, not geographic DNS or measured latency. VPN/proxy exits can affect it. All demo infrastructure is currently destroyed; this new topology has not been exercised live.

Require exact `X-Lab-Origin` and `/api/deployment` provider/mode/storage for all four selected origins: `mode=local`, `storage=redis`, then `mode=shared`, `storage=d1`. A fallback response is not selected-origin proof. GET/HEAD wait at most 2 seconds for response headers per origin before failover; with three stalled origins, reaching the fourth can take about 6 seconds plus its response time. Successful routing sets a healthy-origin affinity cookie. POST is forwarded once, without this read timeout or cross-provider replay. Local read failover can show another cluster's independent dataset; keep healthy-origin affinity for isolation proof. Origin traffic is HTTP port 80; use demo data only.

`GET /state/messages` and `POST /state/messages` require the application bearer token and run before frontend routing, avoiding recursion. Messages include UUID, text, writer provider/region and server-generated timestamp. Reads are bounded to latest 50; text to 500 Unicode codepoints. Identical ID/payload retries return the original result; conflicting reuse fails. SQL parameters are bound, errors are explicit, and no fake/local-memory fallback masks failure. Primary-session reads support cross-provider read-after-write. D1 is Cloudflare-hosted shared storage, not four-cloud database replicas.

The existing zone rejected Python's default User-Agent with 1010; explicit `clouds-lab-rehearsal/1.0`, Go backends and browsers worked without security changes. Provider 5.28 historically refreshed computed D1 `file_size`, `num_tables`, `version` without changing database identity/data or pricing. Review actual plans, not an ignore-all workaround. [Workers](https://developers.cloudflare.com/workers/platform/pricing/) and [D1](https://developers.cloudflare.com/d1/platform/pricing/) Free-plan limits apply; no paid upgrade is approved.

See [two-example cutover evidence](../../RUNBOOK-DETAILED.md#two-example-cutover--2026-10-21), separately from [historical three-example rehearsal](../../RUNBOOK-DETAILED.md#live-rehearsal--2026-10-21). Those observations are not new acceptance checks or timing guarantees.

## Local development boundary

Node 22+ and npm are required for local Wrangler/D1. Install pinned dependencies:

```bash
npm --prefix app/router ci
```

Manually prepare ignored `app/router/.dev.vars` with a **development-only** `STATE_API_TOKEN`, never cloud management credentials or the production token. Start the real local D1 runtime in its own terminal:

```bash
npm --prefix app/router run dev -- --port 8787
```

Local state persists under ignored `app/router/.wrangler`, separate from Terraform/cloud D1. Run two local Go app instances with `APP_MODE=shared`, the same development token and `STATE_API_URL=http://localhost:8787`, distinct loopback ports and explicit provider/region/continent/Pod metadata. A write through one must be readable through the other. Local HTTP is allowed only on loopback; local smoke results are not deployed-cloud proof. Empty frontend origins do not prevent the protected state API from working. For local frontend routing, configure four loopback application host:port origins through Wrangler's supported configuration, not Terraform production origins.

## Approved teardown (optional advanced saved-plan reference)

Explicit approval is required: destroying this root **irreversibly deletes shared D1 messages**, not merely routing. Stop demo use, preserve original credentials/token/state, review the plan and follow [cross-provider cleanup](../../RUNBOOK-DETAILED.md#cleanup): remove routing, release applications while controllers run, then clusters.

```bash
terraform -chdir=infra/cloudflare plan -destroy -out=destroy.tfplan
terraform -chdir=infra/cloudflare show destroy.tfplan
```

After reviewing and approving the irreversible deletion:

```bash
terraform -chdir=infra/cloudflare apply destroy.tfplan
terraform -chdir=infra/cloudflare state list
```

Deleting app Pods/configuration does not delete D1; destroying the database does. Inspect generated custom-domain certificates afterward: deleting a custom domain may leave its certificate. Remove only the approved lab certificate, never the existing zone/domain registration or unrelated resources. Retain state/backups until provider-side deletion is verified; retain shared Docker Hub repository/state across session cleanup.
