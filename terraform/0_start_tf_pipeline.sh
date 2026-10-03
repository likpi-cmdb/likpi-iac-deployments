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
    terraform plan -detailed-exitcode -out=tfplan
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

    local CMDB_URL="${LIKPI_CMDB_URL:-https://localhost:9096}"
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
    find . -type f -name 'likpi.yaml' -print0 > "$FILES_LIST" 2>/dev/null || true

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
import sys
import yaml
import json
from jsonschema import Draft7Validator

file_path = sys.argv[1]
schema_path = sys.argv[2]

with open(schema_path, "r", encoding="utf-8") as f:
    schema = json.load(f)

validator = Draft7Validator(schema)

with open(file_path, "r", encoding="utf-8") as f:
    raw = f.read()

docs = list(yaml.safe_load_all(raw))

has_failure = False
for idx, doc in enumerate(docs):
    if doc is None:
        continue
    doc_name = (doc.get("metadata") or {}).get("name") or f"Doc #{idx + 1}"
    doc_kind = doc.get("kind") or "Unknown"

    errors = list(validator.iter_errors(doc))
    if errors:
        print(f"❌ Validation FAILED for [{doc_name}] ({doc_kind}):", file=sys.stderr)
        for err in errors:
            print(f"  - {err.message} (path: {list(err.absolute_path)})", file=sys.stderr)
        has_failure = True
    else:
        print(f"✅ Passed: [{doc_name}] ({doc_kind})")

sys.exit(1 if has_failure else 0)
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
if tf_init; then
    if tf_plan; then
       echo "Plan OK, proceeding..."
       if tf_apply; then
          update_likpi_cmdb
       fi
    fi
else
  echo "Aborting due to tf init error." >&2
  exit 1
fi
