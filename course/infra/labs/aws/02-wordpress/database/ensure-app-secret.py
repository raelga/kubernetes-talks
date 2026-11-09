#!/usr/bin/env python3
"""Create or refresh nonsecret WordPress connection metadata in Secrets Manager."""

import json
import os
import secrets
import subprocess
import sys
import tempfile

SALT_NAMES = (
    "AUTH_KEY",
    "SECURE_AUTH_KEY",
    "LOGGED_IN_KEY",
    "NONCE_KEY",
    "AUTH_SALT",
    "SECURE_AUTH_SALT",
    "LOGGED_IN_SALT",
    "NONCE_SALT",
)


def aws(*arguments):
    return subprocess.run(
        ["aws", *arguments], capture_output=True, text=True, check=False
    )


def validate(secret):
    return (
        isinstance(secret, dict)
        and secret.get("username") == "wordpress_app"
        and isinstance(secret.get("password"), str)
        and bool(secret["password"])
        and isinstance(secret.get("host"), str)
        and isinstance(secret.get("dbname"), str)
        and (
            "password_version" not in secret
            or (
                type(secret["password_version"]) is int
                and secret["password_version"] >= 1
            )
        )
        and isinstance(secret.get("salts"), dict)
        and all(
            isinstance(secret["salts"].get(name), str) and secret["salts"][name]
            for name in SALT_NAMES
        )
    )


def put_secret(secret_arn, region, secret):
    descriptor, path = tempfile.mkstemp(prefix="wordpress-secret-")
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as secret_file:
            json.dump(secret, secret_file, separators=(",", ":"))
            secret_file.write("\n")
        result = aws(
            "secretsmanager",
            "put-secret-value",
            "--region",
            region,
            "--secret-id",
            secret_arn,
            "--secret-string",
            f"file://{path}",
            "--query",
            "VersionId",
            "--output",
            "text",
        )
        if result.returncode:
            raise RuntimeError("Secrets Manager rejected the application secret update.")
    finally:
        os.unlink(path)


def main():
    if len(sys.argv) != 5:
        raise RuntimeError("Expected secret ARN, region, endpoint and database name.")
    secret_arn, region, endpoint, database = sys.argv[1:]
    result = aws(
        "secretsmanager",
        "get-secret-value",
        "--region",
        region,
        "--secret-id",
        secret_arn,
        "--version-stage",
        "AWSCURRENT",
        "--query",
        "SecretString",
        "--output",
        "text",
    )
    if result.returncode:
        # A newly created secret has metadata but no version yet. Do not mask
        # access, network or other AWS failures as an empty initial secret.
        if "ResourceNotFoundException" not in result.stderr:
            raise RuntimeError("Could not read the current WordPress secret.")
        current = None
    else:
        try:
            current = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise RuntimeError("The current WordPress secret is not valid JSON.") from error
        if not validate(current):
            raise RuntimeError("The current WordPress secret has an unexpected format.")

    if current is None:
        current = {
            "username": "wordpress_app",
            "password": secrets.token_urlsafe(32),
            "host": endpoint,
            "dbname": database,
            "salts": {name: secrets.token_hex(64) for name in SALT_NAMES},
            "password_version": 1,
        }
        message = "Created the WordPress application secret in Secrets Manager."
    elif (
        "password_version" not in current
        or current["host"] != endpoint
        or current["dbname"] != database
    ):
        revision_initialized = "password_version" not in current
        current.setdefault("password_version", 1)
        current["host"] = endpoint
        current["dbname"] = database
        if revision_initialized:
            message = "Initialized the application password revision in Secrets Manager."
        else:
            message = "Updated WordPress database connection metadata in Secrets Manager."
    else:
        print("The WordPress application secret is already current.")
        return

    put_secret(secret_arn, region, current)
    print(message)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        print(f"Application-secret setup failed: {error}", file=sys.stderr)
        raise SystemExit(1)
