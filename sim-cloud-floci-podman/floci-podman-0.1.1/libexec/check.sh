# floci-podman check — verify containers, socket access and a storage round-trip.
#
# Storage is exercised over plain REST with curl so the tool does not need
# awscli + azure-cli + gcloud + oci-cli installed. None of the emulators validate
# credentials by default, so no request signing is required. Every step prints its
# HTTP status, so a failure points straight at the call that broke.

_check_usage() {
  cat <<USAGE
${C_B}floci-podman check${C_0} — verify emulators and storage

  floci-podman check [cloud ...]

For each cloud: container running -> socket reachable inside it -> health endpoint
answers -> create bucket/container, upload, read back and compare, list, clean up.
USAGE
}

for _a in "$@"; do
  case "$_a" in
    -h|--help) _check_usage; return 0 2>/dev/null || exit 0 ;;
  esac
done

CLOUDS=$(floci_pick_clouds "$@") || exit 1
floci_require_podman || exit 1

STAMP=$$
PAYLOAD="floci-podman smoke test ${STAMP}"
FAILED=""
trap 'rm -f "$FLOCI_BODY"' EXIT

try() { # try "label" METHOD URL [curl args...]
  local desc="$1"; shift
  local code snippet
  code=$(req "$@")
  if http_ok "$code"; then
    ok "$desc ${C_DIM}HTTP $code${C_0}"
    return 0
  fi
  bad "$desc ${C_DIM}HTTP $code${C_0}"
  snippet=$(head -c 220 "$FLOCI_BODY" 2>/dev/null | tr '\n\r' '  ')
  [ -n "$snippet" ] && dim "response: $snippet"
  return 1
}

assert_body() { # assert_body "label" expected-substring
  if grep -qF "$2" "$FLOCI_BODY" 2>/dev/null; then
    ok "$1"
    return 0
  fi
  bad "$1 — content mismatch"
  dim "got: $(head -c 220 "$FLOCI_BODY" 2>/dev/null | tr '\n\r' '  ')"
  return 1
}

quiet() { req "$@" >/dev/null 2>&1 || true; }

check_container() { # $1 = cloud
  local name port code rc=0 state candidate found=""
  name=$(floci_cfg "$1" name)
  port=$(floci_cfg "$1" port)

  state=$(floci_container_state "$name")
  if [ "$state" = "running" ]; then
    ok "container $name is running"
  else
    bad "container $name — state: $state"
    dim "start it: floci-podman up $1"
    return 1
  fi

  if podman exec "$name" test -S /var/run/docker.sock 2>/dev/null; then
    ok "docker socket reachable inside the container"
  else
    bad "docker socket NOT reachable inside the container (SELinux or a bad mount)"
    dim "without it compute will fail: Lambda, Functions, ECR, EKS"
    rc=1
  fi

  for candidate in "$(floci_cfg "$1" health)" "/health" "/"; do
    code=$(req GET "http://localhost:${port}${candidate}")
    if http_ok "$code"; then
      found="$candidate"
      break
    fi
  done
  if [ -n "$found" ]; then
    ok "endpoint answers ${C_DIM}${found}${C_0}"
  else
    bad "port $port answered none of the probed paths"
    rc=1
  fi
  return $rc
}

# --- S3 -----------------------------------------------------------------------
smoke_aws() {
  local base bucket rc=0
  base=$(floci_base_url aws)
  bucket="floci-smoke-${STAMP}"

  try "create bucket s3://${bucket}" PUT "${base}/${bucket}" --data-binary '' || rc=1
  try "upload hello.txt" PUT "${base}/${bucket}/hello.txt" \
      -H 'Content-Type: text/plain' --data-binary "$PAYLOAD" || rc=1
  if try "read hello.txt" GET "${base}/${bucket}/hello.txt"; then
    assert_body "object content matches" "$PAYLOAD" || rc=1
  else
    rc=1
  fi
  try "list bucket" GET "${base}/${bucket}" || rc=1

  quiet DELETE "${base}/${bucket}/hello.txt"
  quiet DELETE "${base}/${bucket}"
  return $rc
}

# --- Azure Blob ---------------------------------------------------------------
smoke_az() {
  local base acct ver cont rc=0
  base=$(floci_base_url az)
  acct="$FLOCI_AZ_ACCOUNT"
  ver="2021-08-06"
  cont="floci-smoke-${STAMP}"

  try "create container ${cont}" PUT "${base}/${acct}/${cont}?restype=container" \
      -H "x-ms-version: ${ver}" --data-binary '' || rc=1
  try "upload hello.txt" PUT "${base}/${acct}/${cont}/hello.txt" \
      -H "x-ms-version: ${ver}" -H 'x-ms-blob-type: BlockBlob' \
      -H 'Content-Type: text/plain' --data-binary "$PAYLOAD" || rc=1
  if try "read hello.txt" GET "${base}/${acct}/${cont}/hello.txt" -H "x-ms-version: ${ver}"; then
    assert_body "blob content matches" "$PAYLOAD" || rc=1
  else
    rc=1
  fi
  try "list container" GET "${base}/${acct}/${cont}?restype=container&comp=list" \
      -H "x-ms-version: ${ver}" || rc=1

  quiet DELETE "${base}/${acct}/${cont}/hello.txt" -H "x-ms-version: ${ver}"
  quiet DELETE "${base}/${acct}/${cont}?restype=container" -H "x-ms-version: ${ver}"
  return $rc
}

# --- Google Cloud Storage -----------------------------------------------------
smoke_gcp() {
  local base bucket rc=0
  base=$(floci_base_url gcp)
  bucket="floci-smoke-${STAMP}"

  try "create bucket gs://${bucket}" POST "${base}/storage/v1/b?project=floci-local" \
      -H 'Content-Type: application/json' -d "{\"name\":\"${bucket}\"}" || rc=1
  try "upload hello.txt" POST \
      "${base}/upload/storage/v1/b/${bucket}/o?uploadType=media&name=hello.txt" \
      -H 'Content-Type: text/plain' --data-binary "$PAYLOAD" || rc=1
  if try "read hello.txt" GET "${base}/storage/v1/b/${bucket}/o/hello.txt?alt=media"; then
    assert_body "object content matches" "$PAYLOAD" || rc=1
  else
    rc=1
  fi
  try "list bucket" GET "${base}/storage/v1/b/${bucket}/o" || rc=1

  quiet DELETE "${base}/storage/v1/b/${bucket}/o/hello.txt"
  quiet DELETE "${base}/storage/v1/b/${bucket}"
  return $rc
}

# --- OCI Object Storage -------------------------------------------------------
smoke_oci() {
  local base ns bucket rc=0
  base=$(floci_base_url oci)
  ns="$FLOCI_OCI_NAMESPACE"
  bucket="floci-smoke-${STAMP}"

  try "get namespace" GET "${base}/n/" || rc=1
  try "create bucket ${bucket}" POST "${base}/n/${ns}/b/" \
      -H 'Content-Type: application/json' \
      -d "{\"name\":\"${bucket}\",\"compartmentId\":\"${FLOCI_OCI_TENANCY}\"}" || rc=1
  try "upload hello.txt" PUT "${base}/n/${ns}/b/${bucket}/o/hello.txt" \
      -H 'Content-Type: text/plain' --data-binary "$PAYLOAD" || rc=1
  if try "read hello.txt" GET "${base}/n/${ns}/b/${bucket}/o/hello.txt"; then
    assert_body "object content matches" "$PAYLOAD" || rc=1
  else
    rc=1
  fi
  try "list bucket" GET "${base}/n/${ns}/b/${bucket}/o" || rc=1

  quiet DELETE "${base}/n/${ns}/b/${bucket}/o/hello.txt"
  quiet DELETE "${base}/n/${ns}/b/${bucket}"
  return $rc
}

for cloud in $CLOUDS; do
  label=$(floci_cfg "$cloud" label)
  head1 "${label}  ($(floci_base_url "$cloud"))"

  if ! check_container "$cloud"; then
    FAILED="$FAILED $label"
    continue
  fi

  say ""
  if ! "smoke_${cloud}"; then
    FAILED="$FAILED $label"
  fi
done

head1 "Summary"
if [ -z "$FAILED" ]; then
  ok "all checked clouds passed: $(echo "$CLOUDS" | tr ' ' ',')"
  exit 0
fi
bad "problems in:${FAILED}"
dim "logs for one emulator: podman logs <container-name>"
exit 1
