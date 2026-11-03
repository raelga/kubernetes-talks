#!/usr/bin/env python3
"""Adapta respuestas sintéticas o capturadas al contrato provider/name/location/state."""
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
        raise ValueError(f"campo {field} ausente/no textual")
    return value


def normalize(provider, data):
    if provider == "aws":
        if not isinstance(data, dict) or not isinstance(data.get("Reservations"), list):
            raise ValueError("AWS debe contener Reservations de describe-instances")
        rows = [instance for reservation in data["Reservations"] for instance in reservation["Instances"]]
    else:
        rows = data
    if not isinstance(rows, list):
        raise ValueError("se esperaba una lista de VMs")
    result = []
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("cada VM debe ser un objeto")
        name = row.get("name")
        if provider == "azure":
            location = row.get("location")
            # provisioningState=Succeeded NO indica encendido. Solo PowerState.
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
    parser.add_argument("--input", type=Path, help="JSON envelope; requerido en live")
    parser.add_argument("--running-only", action="store_true")
    args = parser.parse_args()
    if args.mode == "live" and args.input is None:
        parser.error("live requiere --input de capture.py, nunca sustituye una API fallida")
    path = args.input or Path(__file__).resolve().parents[1] / "fixtures" / f"{args.provider}.json"
    try:
        envelope = json.loads(path.read_text(encoding="utf-8"))
        expected_source = "synthetic" if args.mode == "fixture" else "live"
        if envelope["source"] != expected_source or envelope["provider"] != args.provider:
            raise ValueError("source/provider no coinciden con el modo solicitado")
        result = normalize(args.provider, envelope["data"])
        if args.running_only:
            result = [row for row in result if row["state"] == "running"]
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise SystemExit(f"No se pudo normalizar: {exc}")
    print(f"Origen: {expected_source}; proveedor: {args.provider}", file=sys.stderr)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
