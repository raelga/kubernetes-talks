#!/usr/bin/env python3
"""Read-only AWS inventory or explicit analysis of synthetic fixtures."""

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
    """Data, API, scope or verification error; never equivalent to absence."""


def load_json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise InventoryError(f"Expected a JSON object in {path}")
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
            raise InventoryError(f"Missing or invalid Terraform output: {key}")
        result[key] = entry["value"]
    if not re.fullmatch(r"\d{12}", result["account_id"]):
        raise InventoryError("Invalid account_id")
    if not re.fullmatch(r"[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]", result["bucket_name"]):
        raise InventoryError("Invalid bucket name")
    address = ipaddress.IPv4Address(result["public_ip"])
    if result["http_url"] != f"http://{address}/":
        raise InventoryError("http_url does not match the IPv4 in outputs")
    network = ipaddress.IPv4Network(result["client_cidr"])
    if network.prefixlen != 32:
        raise InventoryError("client_cidr must be /32")
    return result


def aws(region: str, *command: str, allow_missing_bucket: bool = False) -> dict | None:
    # Argument list, not a shell; learner parameters are not code.
    result = subprocess.run(
        ["aws", *command, "--region", region, "--output", "json", "--no-cli-pager"],
        capture_output=True, text=True, timeout=60, check=False,
    )
    if result.returncode:
        # Only the exact S3 absence code counts as a deleted bucket.
        if allow_missing_bucket and re.search(r"\(NoSuchBucket\)", result.stderr):
            return None
        raise InventoryError(f"AWS CLI failed ({result.returncode}): {result.stderr.strip()}")
    value = json.loads(result.stdout)
    if not isinstance(value, dict):
        raise InventoryError("AWS CLI did not return a JSON object")
    return value


def collect_live(expected: dict) -> tuple[dict, dict]:
    region = expected["region"]
    identity = aws(region, "sts", "get-caller-identity")
    if identity["Account"] != expected["account_id"]:
        raise InventoryError("Authenticated account does not match outputs; no other environment will be queried")
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
            raise InventoryError(f"Out-of-scope tags in {name}")
        actual = [item[identifier] for item in items]
        wanted = [] if absent else [expected[name]]
        if sorted(actual) != sorted(wanted):
            raise InventoryError(f"{name}: expected {wanted}, observed {actual}")
    if s3["bucket_name"] != expected["bucket_name"] or not isinstance(s3["exists"], bool):
        raise InventoryError("Invalid S3 response or response for another bucket")
    if s3["exists"] == absent:
        raise InventoryError("Bucket state does not match the expectation")
    if absent:
        return {"resources": "absent (terminated EC2 counts as deleted)", "bucket": "absent"}
    if not owned(s3["tagging"], expected, "TagSet"):
        raise InventoryError("Bucket does not have all three ownership tags")
    web = instances[0]
    if web["State"]["Name"] != "running" or web.get("PublicIpAddress") != expected["public_ip"]:
        raise InventoryError("Instance is not running or its IP changed; update outputs")
    if web["VpcId"] != expected["vpc_id"] or web["SubnetId"] != expected["subnet_id"]:
        raise InventoryError("Instance does not belong to the expected network")
    if {group["GroupId"] for group in web["SecurityGroups"]} != {expected["security_group_id"]}:
        raise InventoryError("Instance does not have exclusively the expected SG")
    if web.get("MetadataOptions", {}).get("HttpTokens") != "required":
        raise InventoryError("IMDSv2 is not required")
    if resources["vpc_id"][0][0]["State"] != "available":
        raise InventoryError("VPC is not available")
    subnet = resources["subnet_id"][0][0]
    if subnet["State"] != "available" or subnet["VpcId"] != expected["vpc_id"]:
        raise InventoryError("Subnet is not available in the expected VPC")
    gateway = resources["internet_gateway_id"][0][0]
    if not any(a["VpcId"] == expected["vpc_id"] and a["State"] == "available" for a in gateway["Attachments"]):
        raise InventoryError("Internet gateway is not attached")
    route_table = resources["route_table_id"][0][0]
    if route_table["VpcId"] != expected["vpc_id"] or not any(
        route.get("DestinationCidrBlock") == "0.0.0.0/0"
        and route.get("GatewayId") == expected["internet_gateway_id"]
        and route.get("State") == "active" for route in route_table["Routes"]
    ) or not any(a.get("SubnetId") == expected["subnet_id"] for a in route_table["Associations"]):
        raise InventoryError("Missing Internet route or subnet association")
    sg = resources["security_group_id"][0][0]
    permissions = sg["IpPermissions"]
    if sg["VpcId"] != expected["vpc_id"] or len(permissions) != 1:
        raise InventoryError("SG belongs to another VPC or has additional ingress rules")
    rule = permissions[0]
    if not (
        rule.get("IpProtocol") == "tcp" and rule.get("FromPort") == rule.get("ToPort") == 80
        and rule.get("IpRanges") == [{"CidrIp": expected["client_cidr"], "Description": "Lab client"}]
        and not rule.get("Ipv6Ranges") and not rule.get("UserIdGroupPairs") and not rule.get("PrefixListIds")
    ):
        raise InventoryError("HTTP is not restricted exclusively to the expected /32")
    volume = resources["root_volume_id"][0][0]
    if not volume.get("Encrypted") or volume["State"] != "in-use" or not any(
        attachment["InstanceId"] == expected["instance_id"] and attachment["State"] == "attached"
        for attachment in volume["Attachments"]
    ):
        raise InventoryError("Disk is not encrypted and attached to the expected instance")
    block = s3["public_access_block"]["PublicAccessBlockConfiguration"]
    if not all(block.get(key) is True for key in (
        "BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets",
    )):
        raise InventoryError("S3 public access blocking is incomplete")
    encryption = s3["encryption"]["ServerSideEncryptionConfiguration"]["Rules"]
    if not any(rule.get("ApplyServerSideEncryptionByDefault", {}).get("SSEAlgorithm") == "AES256" for rule in encryption):
        raise InventoryError("S3 AES256 encryption is not configured")
    controls = s3["ownership"]["OwnershipControls"]["Rules"]
    if not any(rule.get("ObjectOwnership") == "BucketOwnerEnforced" for rule in controls):
        raise InventoryError("S3 ACLs are not disabled")
    return {"resources": "present and verified", "bucket": "private, encrypted and ACL-free"}


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise InventoryError("Service returned an unexpected redirect")


def probe(expected: dict) -> None:
    # No proxy or redirects: the request only targets the IPv4 verified in EC2.
    opener = build_opener(ProxyHandler({}), NoRedirect())
    request = Request(expected["http_url"], headers={"Accept": "application/json"})
    with opener.open(request, timeout=5) as response:
        if response.status != 200:
            raise InventoryError(f"Unexpected HTTP status: {response.status}")
        body = response.read(8193)
        if len(body) > 8192:
            raise InventoryError("HTTP response exceeds 8 KiB")
        value = json.loads(body)
    wanted = {"status": "ok", "provider": "aws", "lab_id": expected["lab_id"], "message": expected["message"]}
    if value != wanted:
        raise InventoryError(f"HTTP response differs from expected configuration: {value!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--live", action="store_true", help="Make explicit read-only AWS calls")
    mode.add_argument("--fixture-dir", type=Path, help="No AWS or network; synthetic JSON marked synthetic=true")
    parser.add_argument("--outputs", type=Path, help="File saved with terraform output -json; required in live mode")
    parser.add_argument("--lab-id", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--expect", choices=("present", "absent"), default="present")
    parser.add_argument("--probe-http", action="store_true", help="Live/present only; 5 s timeout, no retries")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-z][a-z0-9-]{2,19}", args.lab_id):
        parser.error("Invalid lab-id")
    if args.live and args.outputs is None:
        parser.error("--live requires --outputs")
    if args.probe_http and (not args.live or args.expect != "present"):
        parser.error("--probe-http is only allowed with --live --expect present")
    try:
        path = args.outputs if args.outputs else args.fixture_dir / "outputs.json"
        expected = read_outputs(path)
        if expected["lab_id"] != args.lab_id or expected["region"] != args.region:
            raise InventoryError("lab-id/region do not match outputs; stopping to protect scope")
        if args.live:
            ec2, s3 = collect_live(expected)
        else:
            ec2 = load_json(args.fixture_dir / "ec2.json")
            s3 = load_json(args.fixture_dir / "s3.json")
            if ec2.get("synthetic") is not True or s3.get("synthetic") is not True:
                raise InventoryError("Fixtures must declare synthetic=true")
        checks = verify(ec2, s3, expected, args.expect == "absent")
        if args.probe_http:
            probe(expected)
        print(json.dumps({
            "mode": "live-read-only" if args.live else "offline-synthetic-NO-CLOUD-VERIFICATION",
            "lab_id": args.lab_id, "region": args.region, "expect": args.expect,
            "checks": checks, "http": "verified" if args.probe_http else "not run",
        }, ensure_ascii=False, indent=2))
        return 0
    except (InventoryError, OSError, ValueError, KeyError, TypeError, IndexError, subprocess.TimeoutExpired, URLError) as error:
        print(f"ERROR: {error}. No success or cleanup is claimed.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
