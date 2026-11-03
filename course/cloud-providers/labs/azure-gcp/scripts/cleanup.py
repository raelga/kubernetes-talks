#!/usr/bin/env python3
"""Comprueba residuos por nombres de propiedad exacta; no borra ni modifica nada."""
import argparse
import json
import re
import subprocess
import sys


def query(command):
    completed = subprocess.run(command, check=True, text=True, capture_output=True)
    rows = json.loads(completed.stdout)
    if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
        raise ValueError("se esperaba una lista JSON de objetos")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["live"])
    parser.add_argument("--provider", choices=["azure", "gcp"], required=True)
    parser.add_argument("--lab-id", required=True)
    parser.add_argument("--subscription")
    parser.add_argument("--project")
    parser.add_argument("--bucket", help="Nombre exacto de bucket_name en los outputs GCP conservados")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,10}[a-z0-9]", args.lab_id):
        parser.error("lab-id debe tener 3–12 caracteres minúsculos/dígitos/guiones")
    prefix = f"upc-2026-cloud-03-{args.lab_id}"
    found = {}
    try:
        if args.provider == "azure":
            if not args.subscription or not re.fullmatch(r"[0-9a-fA-F-]{36}", args.subscription):
                parser.error("Azure requiere --subscription UUID")
            groups = query(["az", "group", "list", "--subscription", args.subscription, "--output", "json"])
            found["resource_groups"] = [row["name"] for row in groups if row.get("name") == prefix]
            if found["resource_groups"]:
                resources = query(["az", "resource", "list", "--subscription", args.subscription,
                                   "--resource-group", prefix, "--output", "json"])
                found["resources"] = [row["id"] for row in resources]
        else:
            if not args.project or not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
                parser.error("GCP requiere --project ID")
            if not args.bucket or not re.fullmatch(r"[a-z0-9][a-z0-9_-]{1,61}[a-z0-9]", args.bucket):
                parser.error("GCP requiere --bucket con el nombre exacto válido de los outputs")
            for kind in ("instances", "disks", "addresses", "networks", "firewalls"):
                rows = query(["gcloud", "compute", kind, "list", "--project", args.project, "--format=json"])
                found[kind] = [row["name"] for row in rows if row.get("name") == prefix or row.get("name", "").startswith(prefix + "-")]
            rows = query(["gcloud", "compute", "networks", "subnets", "list", "--project", args.project, "--format=json"])
            found["subnets"] = [row["name"] for row in rows if row.get("name", "").startswith(prefix + "-")]
            rows = query(["gcloud", "storage", "buckets", "list", "--project", args.project, "--format=json"])
            found["buckets"] = [row["name"] for row in rows if row.get("name", "").removeprefix("gs://").rstrip("/") == args.bucket]
    except subprocess.CalledProcessError as exc:
        print(exc.stderr, file=sys.stderr)
        raise SystemExit("VERIFICACIÓN INCOMPLETA: falló una API/CLI; no equivale a cero recursos")
    except (OSError, ValueError, KeyError, TypeError) as exc:
        raise SystemExit(f"VERIFICACIÓN INCOMPLETA: {exc}")
    print(json.dumps(found, indent=2, sort_keys=True))
    if any(found.values()):
        raise SystemExit("Quedan recursos o el grupo dedicado: revisar el estado exacto; este script no elimina nada")
    print("Sin residuos del alcance consultado. No certifica facturas cerradas ni datos retenidos por el proveedor.")


if __name__ == "__main__":
    main()
