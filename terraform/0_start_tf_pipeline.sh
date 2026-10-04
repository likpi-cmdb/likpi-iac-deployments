#!/bin/sh

set -euo pipefail

export AWS_ENDPOINT_URL=http://localhost:4566
export AWS_DEFAULT_REGION=us-east-1
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

error_handler() {
    local exit_code=$?
    echo "ERROR: Command failed with exit code $exit_code" >&2
}
trap error_handler ERR

# Pipeline in bash
tf_init() {
    echo "🚀 Init Terraform..."

    # Recommended flags for automation:
    # -input=false  -> fail instead of prompting
    # -no-color     -> cleaner logs in CI/CD
    terraform init -input=false -no-color
    local init_exit=$?

    if [[ $init_exit -eq 0 ]]; then
        echo " ✅ Terraform init succeeded."
        return 0
    else
        echo "ERROR: Terraform init failed with exit code $init_exit" >&2
        return 1
    fi
}

tf_plan() {
    echo "📜  Plan ..."

    # Run terraform plan with detailed exit codes:
    # 0 = success, no changes
    # 1 = error
    # 2 = success, changes present
    terraform plan -var-file=$(ls $(pwd)/envs/prod.tfvars) -detailed-exitcode -out=tfplan
    #terraform plan -var-file=”$(ls $(pwd)/envs/prod.tfvars)” -detailed-exitcode -out=tfplan
    local plan_exit=$?

    if [[ $plan_exit -eq 0 ]]; then
        echo "Terraform plan succeeded with no changes."
        return 0
    elif [[ $plan_exit -eq 1 ]]; then
        echo "ERROR: Terraform plan failed." >&2
        return 1
    elif [[ $plan_exit -eq 2 ]]; then
        echo "Terraform plan succeeded with changes pending."
        # Return 0 if “changes” is still considered success for your workflow,
        # or return 2 if you want callers to distinguish this case.
        return 0
    else
        echo "ERROR: Unexpected terraform plan exit code: $plan_exit" >&2
        return 1
    fi
}

function tf_apply {
    echo "🔧 Apply..."
    terraform apply
    return 0
}

update_likpi_cmdb() {
    echo "⬆️  Load to CMDB..."

    echo "🔍 Validating Multi-Document YAML Against Likpi Gatekeeper"

    local CMDB_URL="${LIKPI_CMDB_URL:-http://localhost:9096}"
    local SCHEMA_URL="${CMDB_URL}/api/v1/schema/json-schema"

    # Temporary files
    local SCHEMA_FILE
    local FILES_LIST
    SCHEMA_FILE=$(mktemp)
    FILES_LIST=$(mktemp)

    # Cleanup on function exit
    trap 'rm -f "$SCHEMA_FILE" "$FILES_LIST"' RETURN

    # Fetch schema
    echo "⬇️  Fetching schema from ${SCHEMA_URL} ..."
    if ! curl -fsSL -o "$SCHEMA_FILE" "$SCHEMA_URL"; then
        echo "❌ Failed to fetch live schema from CMDB" >&2
        return 1
    fi

    # Collect likpi.yaml files into a temp file (null-delimited)
    find . -type f -name 'likpi_*.yaml' -print0 > "$FILES_LIST" 2>/dev/null || true

    # Check if we found anything
    if [[ ! -s "$FILES_LIST" ]]; then
        echo "No likpi.yaml files found to validate."
        return 0
    fi

    local has_failure=false
    local file

    # Read null-delimited filenames from the temp file
    while IFS= read -r -d '' file; do
        echo
        echo "🔍 Checking file: ${file}"

        if ! python3 - "$file" "$SCHEMA_FILE" <<'PYEOF'
#!/usr/bin/env python3
"""Validate YAML document(s) against the live CMDB JSON schema.

Usage:
    ./validate.py my-docs.yaml              # HTTP (default)
    ./validate.py my-docs.yaml --https       # HTTPS mode (self-signed OK)
    SCHEME=https ./validate.py my-docs.yaml # env override
Exit codes: 0 = OK, 1 = validation failed, 2 = fetch/parse error.
"""
import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

import yaml
from jsonschema import Draft7Validator

SCHEMA_PATH = "/api/v1/schema/json-schema"


def fetch_schema(scheme, host, port, timeout=10):
    url = f"{scheme}://{host}:{port}{SCHEMA_PATH}"
    print(f"⬇️  Fetching schema from {url} ...")

    ctx = None
    if scheme == "https":
        ctx = ssl.create_default_context()
        # Localhost CMDB: allow self-signed certificates
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    try:
        with urllib.request.urlopen(url, timeout=timeout, context=ctx) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        die(f"CMDB returned HTTP {e.code} for {url}")
    except urllib.error.URLError as e:
        reason = getattr(e, "reason", e)
        if scheme == "https" and "protocol" in str(reason).lower():
            die(f"TLS handshake failed with CMDB ({reason}).\n"
                f"   → Python's TLS backend ({ssl.OPENSSL_VERSION}) cannot negotiate with the server.\n"
                f"   → Try HTTP (default), or use an OpenSSL-backed Python (e.g. brew install python).")
        die(f"Failed to fetch schema from CMDB: {reason}")
    except json.JSONDecodeError as e:
        die(f"CMDB response is not valid JSON ({e}). Is the service really on port {port}?")


def die(msg, code=2):
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(code)


def validate_file(file_path, validator):
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            docs = list(yaml.safe_load_all(f))
    except FileNotFoundError:
        die(f"File not found: {file_path}")
    except yaml.YAMLError as e:
        die(f"Invalid YAML in {file_path}: {e}")

    has_failure = False
    for idx, doc in enumerate(docs):
        if doc is None:
            continue
        if not isinstance(doc, dict):
            print(f"❌ Doc #{idx + 1} in {file_path} is not a mapping "
                  f"(got {type(doc).__name__})", file=sys.stderr)
            has_failure = True
            continue

        doc_name = (doc.get("metadata") or {}).get("name") or f"Doc #{idx + 1}"
        doc_kind = doc.get("kind") or "Unknown"

        errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.absolute_path))
        if errors:
            print(f"❌ Validation FAILED for [{doc_name}] ({doc_kind}):", file=sys.stderr)
            for err in errors:
                print(f"  - {err.message} (path: {list(err.absolute_path)})", file=sys.stderr)
            has_failure = True
        else:
            print(f"✅ Passed: [{doc_name}] ({doc_kind})")
    return has_failure


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("files", nargs="+", help="YAML file(s) to validate")
    ap.add_argument("--https", action="store_true",
                    help="use HTTPS instead of HTTP (default: HTTP)")
    ap.add_argument("--host", default=os.environ.get("CMDB_HOST", "localhost"))
    ap.add_argument("--port", default=int(os.environ.get("CMDB_PORT", "9096")))
    args = ap.parse_args()

    scheme = "https" if (args.https or os.environ.get("SCHEME", "http") == "https") else "http"

    schema = fetch_schema(scheme, args.host, args.port)

    try:
        validator = Draft7Validator(schema)
    except Exception as e:  # not a valid JSON Schema
        die(f"CMDB returned an invalid JSON Schema: {e}")

    has_failure = any(validate_file(f, validator) for f in args.files)
    sys.exit(1 if has_failure else 0)


if __name__ == "__main__":
    main()
PYEOF
        then
            has_failure=true
        fi
    done < "$FILES_LIST"

    if $has_failure; then
        echo
        echo "💥 One or more CIs violated schema constraints. Pull request blocked." >&2
        return 1
    else
        echo
        echo "🚀 All Configuration Items are 100% compliant with Likpi CMDB schema."
        return 0
    fi
}

# Chaining the functions
#rm 'likpi_*.yaml'
if tf_init; then
    if tf_plan; then
       echo "Plan OK, proceeding..."
       if tf_apply; then
          update_likpi_cmdb
       else
          echo "❌ Aborting due to tf Deploy error in Floci." >&2
          exit 1
       fi
    fi
else
  echo "❌ Aborting due to tf init error." >&2
  exit 1
fi
