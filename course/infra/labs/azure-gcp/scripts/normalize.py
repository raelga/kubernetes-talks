#!/usr/bin/env python3
"""Adapt synthetic or captured responses to the provider/name/location/state contract."""
import argparse
import json
from pathlib import Path
import sys


AZURE_STATES = {
    "vm running": "running", "powerstate/running": "running",
    "vm stopped": "stopped", "powerstate/stopped": "stopped",
    "vm deallocated": "stopped", "powerstate/deallocated": "stopped",
    "vm starting": "pending", "powerstate/starting": "pending",
    "vm stopping": "stopping", "powerstate/stopping": "stopping",
    "vm deallocating": "stopping", "powerstate/deallocating": "stopping",
}
GCP_STATES = {"RUNNING": "running", "TERMINATED": "stopped", "STOPPED": "stopped",
              "PROVISIONING": "pending", "STAGING": "pending", "STOPPING": "stopping",
              "SUSPENDED": "suspended", "SUSPENDING": "stopping", "REPAIRING": "pending"}
AWS_STATES = {"running": "running", "stopped": "stopped", "pending": "pending",
              "stopping": "stopping", "shutting-down": "stopping", "terminated": "terminated"}


def required_text(value, field):
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"field {field} missing/not text")
    return value


def normalize(provider, data):
    if provider == "aws":
        if not isinstance(data, dict) or not isinstance(data.get("Reservations"), list):
            raise ValueError("AWS must contain Reservations from describe-instances")
        rows = [instance for reservation in data["Reservations"] for instance in reservation["Instances"]]
    else:
        rows = data
    if not isinstance(rows, list):
        raise ValueError("expected a list of VMs")
    result = []
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("each VM must be an object")
        name = row.get("name")
        if provider == "azure":
            location = row.get("location")
            # provisioningState=Succeeded does NOT indicate running. Use only PowerState.
            power = row.get("powerState")
            if power is None:
                statuses = (row.get("instanceView") or {}).get("statuses", [])
                power = next((s["code"] for s in statuses
                              if isinstance(s.get("code"), str) and s["code"].startswith("PowerState/")), "")
            state = AZURE_STATES.get(required_text(power, "powerState").lower(), "unknown") if power else "unknown"
        elif provider == "gcp":
            location = required_text(row.get("zone"), "zone").rstrip("/").rsplit("/", 1)[-1]
            state = GCP_STATES.get(required_text(row.get("status"), "status"), "unknown")
        else:
            name = next((tag["Value"] for tag in row.get("Tags", []) if tag.get("Key") == "Name"), row.get("InstanceId"))
            location = (row.get("Placement") or {}).get("AvailabilityZone")
            state = AWS_STATES.get(required_text((row.get("State") or {}).get("Name"), "State.Name"), "unknown")
        result.append({"provider": provider, "name": required_text(name, "name"),
                       "location": required_text(location, "location"), "state": state})
    return sorted(result, key=lambda row: (row["provider"], row["name"], row["location"], row["state"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["fixture", "live"])
    parser.add_argument("--provider", choices=["aws", "azure", "gcp"], required=True)
    parser.add_argument("--input", type=Path, help="JSON envelope; required in live mode")
    parser.add_argument("--running-only", action="store_true")
    args = parser.parse_args()
    if args.mode == "live" and args.input is None:
        parser.error("live requires --input from capture.py; it never substitutes for a failed API")
    path = args.input or Path(__file__).resolve().parents[1] / "fixtures" / f"{args.provider}.json"
    try:
        envelope = json.loads(path.read_text(encoding="utf-8"))
        expected_source = "synthetic" if args.mode == "fixture" else "live"
        if envelope["source"] != expected_source or envelope["provider"] != args.provider:
            raise ValueError("source/provider do not match the requested mode")
        result = normalize(args.provider, envelope["data"])
        if args.running_only:
            result = [row for row in result if row["state"] == "running"]
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise SystemExit(f"Could not normalize: {exc}")
    print(f"Source: {expected_source}; provider: {args.provider}", file=sys.stderr)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
