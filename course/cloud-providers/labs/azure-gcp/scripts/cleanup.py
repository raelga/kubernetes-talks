#!/usr/bin/env python3
"""Check residual resources by exact ownership names; delete or modify nothing."""
import argparse
import json
import re
import subprocess
import sys


def query(command):
    completed = subprocess.run(command, check=True, text=True, capture_output=True)
    rows = json.loads(completed.stdout)
    if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
        raise ValueError("expected a JSON list of objects")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["live"])
    parser.add_argument("--provider", choices=["azure", "gcp"], required=True)
    parser.add_argument("--lab-id", required=True)
    parser.add_argument("--subscription")
    parser.add_argument("--project")
    parser.add_argument("--bucket", help="Exact bucket_name from preserved GCP outputs")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,10}[a-z0-9]", args.lab_id):
        parser.error("lab-id must have 3–12 lowercase letters/digits/hyphens")
    prefix = f"upc-2026-cloud-03-{args.lab_id}"
    found = {}
    try:
        if args.provider == "azure":
            if not args.subscription or not re.fullmatch(r"[0-9a-fA-F-]{36}", args.subscription):
                parser.error("Azure requires --subscription UUID")
            groups = query(["az", "group", "list", "--subscription", args.subscription, "--output", "json"])
            found["resource_groups"] = [row["name"] for row in groups if row.get("name") == prefix]
            if found["resource_groups"]:
                resources = query(["az", "resource", "list", "--subscription", args.subscription,
                                   "--resource-group", prefix, "--output", "json"])
                found["resources"] = [row["id"] for row in resources]
        else:
            if not args.project or not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
                parser.error("GCP requires --project ID")
            if not args.bucket or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]", args.bucket):
                parser.error("GCP requires --bucket with the exact valid name from outputs")
            for kind in ("instances", "disks", "addresses", "networks", "firewalls"):
                rows = query(["gcloud", "compute", kind, "list", "--project", args.project, "--format=json"])
                found[kind] = [row["name"] for row in rows if row.get("name") == prefix or row.get("name", "").startswith(prefix + "-")]
            rows = query(["gcloud", "compute", "networks", "subnets", "list", "--project", args.project, "--format=json"])
            found["subnets"] = [row["name"] for row in rows if row.get("name", "").startswith(prefix + "-")]
            rows = query(["gcloud", "storage", "buckets", "list", "--project", args.project, "--format=json"])
            found["buckets"] = [row["name"] for row in rows if row.get("name", "").removeprefix("gs://").rstrip("/") == args.bucket]
    except subprocess.CalledProcessError as exc:
        print(exc.stderr, file=sys.stderr)
        raise SystemExit("VERIFICATION INCOMPLETE: an API/CLI failed; this does not mean zero resources")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(f"VERIFICATION INCOMPLETE: {exc}")
    print(json.dumps(found, indent=2, sort_keys=True))
    if any(found.values()):
        raise SystemExit("Resources or the dedicated group remain: review the exact state; this script deletes nothing")
    print("No residual resources in the queried scope. This does not certify closed bills or provider-retained data.")


if __name__ == "__main__":
    main()
