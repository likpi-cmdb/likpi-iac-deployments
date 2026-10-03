#!/usr/bin/env bash
# floci-lib.sh — shared configuration and helpers. Sourced by bin/floci-podman.
#
# Why this project exists: `floci start` bind-mounts the Docker socket without the
# `:z` SELinux relabel. Inside a podman machine (Fedora CoreOS) the container is
# then denied access to the socket, and every compute service that spawns its own
# container — Lambda, Azure Functions, Cloud Functions, ECR, EKS, CodeBuild —
# fails, usually with `java.io.IOException: Broken pipe`.

FLOCI_CLOUDS_ALL="aws az gcp oci"
FLOCI_NETWORK="${FLOCI_NETWORK:-floci-net}"
FLOCI_AWS_REGION="${FLOCI_AWS_REGION:-us-east-1}"
FLOCI_OCI_NAMESPACE="${FLOCI_OCI_NAMESPACE:-floci-local}"
FLOCI_OCI_TENANCY="${FLOCI_OCI_TENANCY:-ocid1.tenancy.oc1..flocilocaltenancy0000000000000000000000000000000000000000}"
FLOCI_AZ_ACCOUNT="${FLOCI_AZ_ACCOUNT:-devstoreaccount1}"
FLOCI_AZ_KEY="${FLOCI_AZ_KEY:-Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMh0==}"

# --- output -------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_WARN=$'\033[33m'; C_DIM=$'\033[2m'
  C_B=$'\033[1m'; C_CY=$'\033[36m'; C_0=$'\033[0m'
else
  C_OK=""; C_ERR=""; C_WARN=""; C_DIM=""; C_B=""; C_CY=""; C_0=""
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_OK" "$C_0" "$*"; }
bad()  { printf '  %s✗%s %s\n' "$C_ERR" "$C_0" "$*"; }
warn() { printf '  %s⚠%s %s\n' "$C_WARN" "$C_0" "$*"; }
dim()  { printf '    %s%s%s\n' "$C_DIM" "$*" "$C_0"; }
head1(){ printf '\n%s%s%s\n' "$C_B" "$*" "$C_0"; }
rule() { printf '%s──────────────────────────────────────────────────────────────%s\n' "$C_DIM" "$C_0"; }

# --- per-cloud configuration --------------------------------------------------
# macOS ships bash 3.2, which has no associative arrays. Hence the case block.
floci_cfg() {
  case "$1:$2" in
    aws:image)  echo "docker.io/floci/floci:latest" ;;
    aws:name)   echo "floci" ;;
    aws:port)   echo "4566" ;;
    aws:health) echo "/_floci/health" ;;
    aws:label)  echo "AWS" ;;

    az:image)   echo "docker.io/floci/floci-az:latest" ;;
    az:name)    echo "floci-az" ;;
    az:port)    echo "4577" ;;
    az:health)  echo "/_floci-az/health" ;;
    az:label)   echo "Azure" ;;

    gcp:image)  echo "docker.io/floci/floci-gcp:latest" ;;
    gcp:name)   echo "floci-gcp" ;;
    gcp:port)   echo "4588" ;;
    gcp:health) echo "/_floci-gcp/health" ;;
    gcp:label)  echo "GCP" ;;

    oci:image)  echo "docker.io/floci/floci-oci:latest" ;;
    oci:name)   echo "floci-oci" ;;
    oci:port)   echo "4599" ;;
    oci:health) echo "/_floci-oci/health" ;;
    oci:label)  echo "OCI" ;;

    *) return 1 ;;
  esac
}

floci_base_url() { echo "http://localhost:$(floci_cfg "$1" port)"; }

# Echo the requested clouds, or all of them when none were given.
floci_pick_clouds() {
  if [ "$#" -eq 0 ]; then
    echo "$FLOCI_CLOUDS_ALL"
    return 0
  fi
  local c out=""
  for c in "$@"; do
    if ! floci_cfg "$c" name >/dev/null 2>&1; then
      printf 'floci-podman: unknown cloud %s (expected one of: %s)\n' "$c" "$FLOCI_CLOUDS_ALL" >&2
      return 1
    fi
    out="$out $c"
  done
  echo "${out# }"
}

# --- connection details -------------------------------------------------------
# Bare `export` lines, suitable for eval.
floci_conn_exports() {
  local base port
  base=$(floci_base_url "$1")
  port=$(floci_cfg "$1" port)
  case "$1" in
    aws)
      echo "export AWS_ENDPOINT_URL=${base}"
      echo "export AWS_ACCESS_KEY_ID=test"
      echo "export AWS_SECRET_ACCESS_KEY=test"
      echo "export AWS_DEFAULT_REGION=${FLOCI_AWS_REGION}"
      ;;
    az)
      echo "export AZURE_STORAGE_CONNECTION_STRING=\"DefaultEndpointsProtocol=http;AccountName=${FLOCI_AZ_ACCOUNT};AccountKey=${FLOCI_AZ_KEY};BlobEndpoint=${base}/${FLOCI_AZ_ACCOUNT};QueueEndpoint=${base}/${FLOCI_AZ_ACCOUNT};TableEndpoint=${base}/${FLOCI_AZ_ACCOUNT};\""
      echo "export AZURE_STORAGE_ACCOUNT=${FLOCI_AZ_ACCOUNT}"
      ;;
    gcp)
      # STORAGE_EMULATOR_HOST wants a scheme; the others are bare host:port.
      echo "export STORAGE_EMULATOR_HOST=${base}"
      echo "export PUBSUB_EMULATOR_HOST=localhost:${port}"
      echo "export FIRESTORE_EMULATOR_HOST=localhost:${port}"
      echo "export DATASTORE_EMULATOR_HOST=localhost:${port}"
      echo "export GOOGLE_CLOUD_PROJECT=floci-local"
      ;;
    oci)
      echo "export OCI_CLI_ENDPOINT=${base}"
      echo "export OCI_NAMESPACE=${FLOCI_OCI_NAMESPACE}"
      echo "export TENANCY_OCID=${FLOCI_OCI_TENANCY}"
      ;;
  esac
}

floci_print_conn() {
  local cloud="$1" base label line
  base=$(floci_base_url "$cloud")
  label=$(floci_cfg "$cloud" label)

  printf '\n%s%s%s  %s%s%s\n' "$C_B" "$label" "$C_0" "$C_CY" "$base" "$C_0"

  floci_conn_exports "$cloud" | while IFS= read -r line; do
    printf '  %s\n' "$line"
  done

  case "$cloud" in
    aws)
      dim "SDK: enable path-style addressing (UsePathStyle=true / forcePathStyle(true))"
      dim "try: aws --endpoint-url ${base} s3 ls"
      ;;
    az)
      dim "${FLOCI_AZ_ACCOUNT} is the well-known Azurite account; floci does not validate it"
      dim "try: az storage container list --connection-string \"\$AZURE_STORAGE_CONNECTION_STRING\""
      ;;
    gcp)
      dim "credentials are not validated; use NoCredentials in the SDK"
      dim "try: gcloud storage ls"
      ;;
    oci)
      dim "API key: floci oci setup (writes ~/.oci/config)"
      dim "try: oci os ns get --endpoint ${base}"
      ;;
  esac

  if command -v floci >/dev/null 2>&1; then
    dim "authoritative values: eval \"\$(floci ${cloud} env)\""
  fi
}

# --- podman -------------------------------------------------------------------
floci_require_podman() {
  if ! command -v podman >/dev/null 2>&1; then
    say "floci-podman: podman not found in PATH. Install it with: brew install podman" >&2
    return 1
  fi
  if ! podman info >/dev/null 2>&1; then
    say "floci-podman: the podman machine is not responding. Start it with: podman machine start" >&2
    return 1
  fi
  return 0
}

# Path to the podman socket *inside the VM* — not on the host.
# This is what gets bind-mounted; it does not and should not exist on macOS.
floci_socket_path() {
  if [ -n "${FLOCI_PODMAN_SOCK:-}" ]; then
    echo "$FLOCI_PODMAN_SOCK"
    return 0
  fi
  local uid
  uid=$(podman machine ssh 'id -u' 2>/dev/null | tr -d '\r' | tail -n 1)
  case "$uid" in
    ''|*[!0-9]*) uid=0 ;;
  esac
  echo "/run/user/${uid}/podman/podman.sock"
}

floci_container_state() {
  podman inspect -f '{{.State.Status}}' "$1" 2>/dev/null || echo "absent"
}

# --- HTTP ---------------------------------------------------------------------
FLOCI_BODY="${TMPDIR:-/tmp}/floci-podman-resp.$$"
req() {
  local method="$1" url="$2"; shift 2
  curl -sS --max-time 20 -o "$FLOCI_BODY" -w '%{http_code}' -X "$method" "$@" "$url" 2>/dev/null || echo "000"
}
http_ok() { case "$1" in 2??) return 0 ;; *) return 1 ;; esac; }
