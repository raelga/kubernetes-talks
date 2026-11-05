#!/usr/bin/env python3
"""Explicit VM capture; invokes only read-only commands and never creates resources."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["live"], help="No fallback to fixtures")
    parser.add_argument("--provider", choices=["azure", "gcp"], required=True)
    parser.add_argument("--lab-id", required=True)
    parser.add_argument("--subscription", help="Azure UUID")
    parser.add_argument("--resource-group", help="Exact resource group created by this lab")
    parser.add_argument("--project", help="Explicit GCP project ID")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,10}[a-z0-9]", args.lab_id):
        parser.error("lab-id must have 3–12 lowercase letters/digits/hyphens")
    expected = {"course": "upc-2026", "lab": "cloud-03", "lab_id": args.lab_id}
    if args.provider == "azure":
        if not args.subscription or not re.fullmatch(r"[0-9a-fA-F-]{36}", args.subscription):
            parser.error("Azure requires an explicit --subscription UUID")
        if args.resource_group != f"upc-2026-cloud-03-{args.lab_id}":
            parser.error("--resource-group must match lab-id exactly")
        command = ["az", "vm", "list", "--show-details", "--subscription", args.subscription,
                   "--resource-group", args.resource_group, "--output", "json"]
        scope = {"subscription": args.subscription, "resource_group": args.resource_group}
        label_key = "tags"
    else:
        if not args.project or not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
            parser.error("GCP requires an explicit --project ID")
        filters = " AND ".join(f"labels.{key}={value}" for key, value in expected.items())
        command = ["gcloud", "compute", "instances", "list", "--project", args.project,
                   "--filter", filters, "--format=json"]
        scope = {"project": args.project}
        label_key = "labels"
    try:
        response = subprocess.run(command, check=True, capture_output=True, text=True)
        rows = json.loads(response.stdout)
        if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
            raise ValueError("the CLI did not return a list of objects")
        rows = [row for row in rows if all((row.get(label_key) or {}).get(key) == value
                                          for key, value in expected.items())]
        envelope = {"source": "live", "provider": args.provider, "scope": scope,
                    "ownership": expected, "data": rows}
        # 'x' prevents accidentally overwriting previous evidence.
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(envelope, stream, indent=2, sort_keys=True)
            stream.write("\n")
    except subprocess.CalledProcessError as exc:
        print(exc.stderr, file=sys.stderr)
        raise SystemExit(f"API/CLI failed ({exc.returncode}); no capture was created and empty inventory was not assumed")
    except (OSError, ValueError, TypeError) as exc:
        raise SystemExit(f"Invalid capture: {exc}")
    print(f"Live capture: {len(rows)} VM(s) with exact ownership; does not prove absence of other resource types.")


if __name__ == "__main__":
    main()
