#!/usr/bin/env python3
"""Captura explícita de VMs; solo invoca comandos de lectura, nunca crea recursos."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["live"], help="No hay fallback a fixtures")
    parser.add_argument("--provider", choices=["azure", "gcp"], required=True)
    parser.add_argument("--lab-id", required=True)
    parser.add_argument("--subscription", help="UUID Azure")
    parser.add_argument("--resource-group", help="Grupo exacto creado por este laboratorio")
    parser.add_argument("--project", help="ID explícito del proyecto GCP")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{1,10}[a-z0-9]", args.lab_id):
        parser.error("lab-id debe tener 3–12 caracteres minúsculos/dígitos/guiones")
    expected = {"course": "upc-2026", "lab": "cloud-03", "lab_id": args.lab_id}
    if args.provider == "azure":
        if not args.subscription or not re.fullmatch(r"[0-9a-fA-F-]{36}", args.subscription):
            parser.error("Azure requiere --subscription UUID explícito")
        if args.resource_group != f"upc-2026-cloud-03-{args.lab_id}":
            parser.error("--resource-group debe coincidir exactamente con el lab-id")
        command = ["az", "vm", "list", "--show-details", "--subscription", args.subscription,
                   "--resource-group", args.resource_group, "--output", "json"]
        scope = {"subscription": args.subscription, "resource_group": args.resource_group}
        label_key = "tags"
    else:
        if not args.project or not re.fullmatch(r"[a-z][a-z0-9-]{4,28}[a-z0-9]", args.project):
            parser.error("GCP requiere --project ID explícito")
        filters = " AND ".join(f"labels.{key}={value}" for key, value in expected.items())
        command = ["gcloud", "compute", "instances", "list", "--project", args.project,
                   "--filter", filters, "--format=json"]
        scope = {"project": args.project}
        label_key = "labels"
    try:
        response = subprocess.run(command, check=True, capture_output=True, text=True)
        rows = json.loads(response.stdout)
        if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
            raise ValueError("la CLI no devolvió una lista de objetos")
        rows = [row for row in rows if all((row.get(label_key) or {}).get(key) == value
                                          for key, value in expected.items())]
        envelope = {"source": "live", "provider": args.provider, "scope": scope,
                    "ownership": expected, "data": rows}
        # 'x' impide sobrescribir accidentalmente una evidencia previa.
        with args.output.open("x", encoding="utf-8") as stream:
            json.dump(envelope, stream, indent=2, sort_keys=True)
            stream.write("\n")
    except subprocess.CalledProcessError as exc:
        print(exc.stderr, file=sys.stderr)
        raise SystemExit(f"Falló la API/CLI ({exc.returncode}); no se creó una captura ni se asumió inventario vacío")
    except (OSError, ValueError, TypeError) as exc:
        raise SystemExit(f"Captura inválida: {exc}")
    print(f"Captura live: {len(rows)} VM(s) con propiedad exacta; no demuestra ausencia de otros tipos de recurso.")


if __name__ == "__main__":
    main()
