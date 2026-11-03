#!/usr/bin/env python3
"""Inventario AWS de solo lectura o análisis explícito de fixtures sintéticas."""

import argparse
import ipaddress
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.error import URLError
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener


class InventoryError(Exception):
    """Error de datos, API, alcance o comprobación; nunca equivale a ausencia."""


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise InventoryError(f"Se esperaba un objeto JSON en {path}")
    return value


def read_outputs(path: Path) -> dict:
    raw = load_json(path)
    keys = (
        "lab_id", "region", "account_id", "client_cidr", "message", "instance_id",
        "vpc_id", "subnet_id", "internet_gateway_id", "route_table_id",
        "security_group_id", "root_volume_id", "bucket_name", "public_ip", "http_url",
    )
    result = {}
    for key in keys:
        entry = raw.get(key)
        if not isinstance(entry, dict) or not isinstance(entry.get("value"), str) or not entry["value"]:
            raise InventoryError(f"Output Terraform ausente o inválido: {key}")
        result[key] = entry["value"]
    if not re.fullmatch(r"\d{12}", result["account_id"]):
        raise InventoryError("account_id no válido")
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", result["bucket_name"]):
        raise InventoryError("Nombre de bucket no válido")
    address = ipaddress.IPv4Address(result["public_ip"])
    if result["http_url"] != f"http://{address}/":
        raise InventoryError("http_url no coincide con la IPv4 de los outputs")
    network = ipaddress.IPv4Network(result["client_cidr"])
    if network.prefixlen != 32:
        raise InventoryError("client_cidr debe ser /32")
    return result


def aws(region: str, *command: str, allow_missing_bucket: bool = False) -> dict | None:
    # Lista de argumentos, no shell; los parámetros del alumno no son código.
    result = subprocess.run(
        ["aws", *command, "--region", region, "--output", "json", "--no-cli-pager"],
        capture_output=True, text=True, timeout=60, check=False,
    )
    if result.returncode:
        # Solo el código exacto de ausencia de S3 cuenta como bucket eliminado.
        if allow_missing_bucket and re.search(r"\(NoSuchBucket\)", result.stderr):
            return None
        raise InventoryError(f"AWS CLI falló ({result.returncode}): {result.stderr.strip()}")
    value = json.loads(result.stdout)
    if not isinstance(value, dict):
        raise InventoryError("AWS CLI no devolvió un objeto JSON")
    return value


def collect_live(expected: dict) -> tuple[dict, dict]:
    region = expected["region"]
    identity = aws(region, "sts", "get-caller-identity")
    if identity["Account"] != expected["account_id"]:
        raise InventoryError("La cuenta autenticada no coincide con los outputs; no se consulta otro entorno")
    filters = [
        "Name=tag:course,Values=upc-2026",
        "Name=tag:lab,Values=cloud-02",
        f"Name=tag:lab_id,Values={expected['lab_id']}",
    ]
    ec2 = {}
    for name, operation in (
        ("instances", "describe-instances"), ("vpcs", "describe-vpcs"),
        ("subnets", "describe-subnets"), ("internet_gateways", "describe-internet-gateways"),
        ("route_tables", "describe-route-tables"), ("security_groups", "describe-security-groups"),
        ("volumes", "describe-volumes"),
    ):
        ec2[name] = aws(region, "ec2", operation, "--filters", *filters)
    bucket = expected["bucket_name"]
    tags = aws(region, "s3api", "get-bucket-tagging", "--bucket", bucket, allow_missing_bucket=True)
    s3 = {"bucket_name": bucket, "exists": tags is not None}
    if tags is not None:
        s3["tagging"] = tags
        s3["public_access_block"] = aws(region, "s3api", "get-public-access-block", "--bucket", bucket)
        s3["encryption"] = aws(region, "s3api", "get-bucket-encryption", "--bucket", bucket)
        s3["ownership"] = aws(region, "s3api", "get-bucket-ownership-controls", "--bucket", bucket)
    return ec2, s3


def owned(item: dict, expected: dict, key: str = "Tags") -> bool:
    tags = {tag["Key"]: tag["Value"] for tag in item.get(key, [])}
    return all(tags.get(k) == v for k, v in {
        "course": "upc-2026", "lab": "cloud-02", "lab_id": expected["lab_id"],
    }.items())


def verify(ec2: dict, s3: dict, expected: dict, absent: bool) -> dict:
    instances = [
        instance for reservation in ec2["instances"]["Reservations"]
        for instance in reservation["Instances"]
        if instance["State"]["Name"] != "terminated"
    ]
    resources = {
        "instance_id": (instances, "InstanceId"),
        "vpc_id": (ec2["vpcs"]["Vpcs"], "VpcId"),
        "subnet_id": (ec2["subnets"]["Subnets"], "SubnetId"),
        "internet_gateway_id": (ec2["internet_gateways"]["InternetGateways"], "InternetGatewayId"),
        "route_table_id": (ec2["route_tables"]["RouteTables"], "RouteTableId"),
        "security_group_id": (ec2["security_groups"]["SecurityGroups"], "GroupId"),
        "root_volume_id": (ec2["volumes"]["Volumes"], "VolumeId"),
    }
    for name, (items, identifier) in resources.items():
        if any(not owned(item, expected) for item in items):
            raise InventoryError(f"Etiquetas fuera del alcance en {name}")
        actual = [item[identifier] for item in items]
        wanted = [] if absent else [expected[name]]
        if sorted(actual) != sorted(wanted):
            raise InventoryError(f"{name}: esperado {wanted}, observado {actual}")
    if s3["bucket_name"] != expected["bucket_name"] or not isinstance(s3["exists"], bool):
        raise InventoryError("Respuesta S3 inválida o de otro bucket")
    if s3["exists"] == absent:
        raise InventoryError("El estado del bucket no coincide con la expectativa")
    if absent:
        return {"resources": "ausentes (EC2 terminated se considera eliminado)", "bucket": "ausente"}
    if not owned(s3["tagging"], expected, "TagSet"):
        raise InventoryError("El bucket no tiene las tres etiquetas de propiedad")
    web = instances[0]
    if web["State"]["Name"] != "running" or web.get("PublicIpAddress") != expected["public_ip"]:
        raise InventoryError("La instancia no está running o su IP cambió; actualiza los outputs")
    if web["VpcId"] != expected["vpc_id"] or web["SubnetId"] != expected["subnet_id"]:
        raise InventoryError("La instancia no pertenece a la red esperada")
    if {group["GroupId"] for group in web["SecurityGroups"]} != {expected["security_group_id"]}:
        raise InventoryError("La instancia no tiene exclusivamente el SG esperado")
    if web.get("MetadataOptions", {}).get("HttpTokens") != "required":
        raise InventoryError("IMDSv2 no es obligatorio")
    if resources["vpc_id"][0][0]["State"] != "available":
        raise InventoryError("La VPC no está disponible")
    subnet = resources["subnet_id"][0][0]
    if subnet["State"] != "available" or subnet["VpcId"] != expected["vpc_id"]:
        raise InventoryError("La subred no está disponible en la VPC esperada")
    gateway = resources["internet_gateway_id"][0][0]
    if not any(a["VpcId"] == expected["vpc_id"] and a["State"] == "available" for a in gateway["Attachments"]):
        raise InventoryError("La puerta de Internet no está conectada")
    route_table = resources["route_table_id"][0][0]
    if route_table["VpcId"] != expected["vpc_id"] or not any(
        route.get("DestinationCidrBlock") == "0.0.0.0/0"
        and route.get("GatewayId") == expected["internet_gateway_id"]
        and route.get("State") == "active" for route in route_table["Routes"]
    ) or not any(a.get("SubnetId") == expected["subnet_id"] for a in route_table["Associations"]):
        raise InventoryError("Ruta de Internet o asociación de subred ausente")
    sg = resources["security_group_id"][0][0]
    permissions = sg["IpPermissions"]
    if sg["VpcId"] != expected["vpc_id"] or len(permissions) != 1:
        raise InventoryError("SG en otra VPC o con entradas adicionales")
    rule = permissions[0]
    if not (
        rule.get("IpProtocol") == "tcp" and rule.get("FromPort") == rule.get("ToPort") == 80
        and rule.get("IpRanges") == [{"CidrIp": expected["client_cidr"], "Description": "Cliente del laboratorio"}]
        and not rule.get("Ipv6Ranges") and not rule.get("UserIdGroupPairs") and not rule.get("PrefixListIds")
    ):
        raise InventoryError("HTTP no está restringido exclusivamente al /32 esperado")
    volume = resources["root_volume_id"][0][0]
    if not volume.get("Encrypted") or volume["State"] != "in-use" or not any(
        attachment["InstanceId"] == expected["instance_id"] and attachment["State"] == "attached"
        for attachment in volume["Attachments"]
    ):
        raise InventoryError("El disco no está cifrado y conectado a la instancia esperada")
    block = s3["public_access_block"]["PublicAccessBlockConfiguration"]
    if not all(block.get(key) is True for key in (
        "BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets",
    )):
        raise InventoryError("El bloqueo de acceso público S3 no está completo")
    encryption = s3["encryption"]["ServerSideEncryptionConfiguration"]["Rules"]
    if not any(rule.get("ApplyServerSideEncryptionByDefault", {}).get("SSEAlgorithm") == "AES256" for rule in encryption):
        raise InventoryError("El cifrado S3 AES256 no está configurado")
    controls = s3["ownership"]["OwnershipControls"]["Rules"]
    if not any(rule.get("ObjectOwnership") == "BucketOwnerEnforced" for rule in controls):
        raise InventoryError("Las ACL S3 no están deshabilitadas")
    return {"resources": "presentes y comprobados", "bucket": "privado, cifrado y sin ACL"}


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise InventoryError("El servicio respondió una redirección inesperada")


def probe(expected: dict) -> None:
    # Sin proxy ni redirecciones: la petición solo va a la IPv4 comprobada en EC2.
    opener = build_opener(ProxyHandler({}), NoRedirect())
    request = Request(expected["http_url"], headers={"Accept": "application/json"})
    with opener.open(request, timeout=5) as response:
        if response.status != 200:
            raise InventoryError(f"HTTP inesperado: {response.status}")
        body = response.read(8193)
        if len(body) > 8192:
            raise InventoryError("La respuesta HTTP excede 8 KiB")
        value = json.loads(body)
    wanted = {"status": "ok", "provider": "aws", "lab_id": expected["lab_id"], "message": expected["message"]}
    if value != wanted:
        raise InventoryError(f"Respuesta HTTP distinta de la configuración esperada: {value!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--live", action="store_true", help="Realiza llamadas AWS explícitas de solo lectura")
    mode.add_argument("--fixture-dir", type=Path, help="Sin AWS ni red; JSON sintético marcado synthetic=true")
    parser.add_argument("--outputs", type=Path, help="Fichero guardado con terraform output -json; obligatorio en vivo")
    parser.add_argument("--lab-id", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--expect", choices=("present", "absent"), default="present")
    parser.add_argument("--probe-http", action="store_true", help="Solo en vivo/present; timeout 5 s, sin reintentos")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,19}", args.lab_id):
        parser.error("lab-id no válido")
    if args.live and args.outputs is None:
        parser.error("--live requiere --outputs")
    if args.probe_http and (not args.live or args.expect != "present"):
        parser.error("--probe-http solo se permite con --live --expect present")
    try:
        path = args.outputs if args.outputs else args.fixture_dir / "outputs.json"
        expected = read_outputs(path)
        if expected["lab_id"] != args.lab_id or expected["region"] != args.region:
            raise InventoryError("lab-id/región no coinciden con los outputs; detención para proteger el alcance")
        if args.live:
            ec2, s3 = collect_live(expected)
        else:
            ec2 = load_json(args.fixture_dir / "ec2.json")
            s3 = load_json(args.fixture_dir / "s3.json")
            if ec2.get("synthetic") is not True or s3.get("synthetic") is not True:
                raise InventoryError("Las fixtures deben declarar synthetic=true")
        checks = verify(ec2, s3, expected, args.expect == "absent")
        if args.probe_http:
            probe(expected)
        print(json.dumps({
            "mode": "live-read-only" if args.live else "offline-synthetic-NO-CLOUD-VERIFICATION",
            "lab_id": args.lab_id, "region": args.region, "expect": args.expect,
            "checks": checks, "http": "comprobado" if args.probe_http else "no ejecutado",
        }, ensure_ascii=False, indent=2))
        return 0
    except (InventoryError, OSError, ValueError, KeyError, TypeError, IndexError, subprocess.TimeoutExpired, URLError) as error:
        print(f"ERROR: {error}. No se declara éxito ni limpieza.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
