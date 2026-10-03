# floci-podman up — start emulators with a correctly relabelled socket mount.
# Sourced by bin/floci-podman; "$@" holds the arguments after the subcommand.

_up_usage() {
  cat <<USAGE
${C_B}floci-podman up${C_0} — start Floci emulators on Podman

  floci-podman up [cloud ...]

Starts each requested emulator (all four when none are named), waits for it to
answer, verifies the Docker socket is reachable inside the container, and prints
connection details for everything that came up.

Options:
  -h, --help    show this help
USAGE
}

for _a in "$@"; do
  case "$_a" in
    -h|--help) _up_usage; return 0 2>/dev/null || exit 0 ;;
  esac
done

CLOUDS=$(floci_pick_clouds "$@") || exit 1
floci_require_podman || exit 1

if [ -n "${DOCKER_HOST:-}" ]; then
  warn "DOCKER_HOST is set to: $DOCKER_HOST"
  dim "podman ignores it, but the floci CLI and Testcontainers do not. If it points"
  dim "at a socket that does not exist, drop the line from your shell profile."
fi

SOCK=$(floci_socket_path)
head1 "Podman socket (path inside the VM): $SOCK"
dim "This path does not exist on the host, and should not — containers live in the VM."

if podman network exists "$FLOCI_NETWORK" 2>/dev/null; then
  ok "network $FLOCI_NETWORK already exists"
elif podman network create "$FLOCI_NETWORK" >/dev/null; then
  ok "created network $FLOCI_NETWORK"
else
  bad "could not create network $FLOCI_NETWORK"
  exit 1
fi

STARTED=""
for cloud in $CLOUDS; do
  name=$(floci_cfg "$cloud" name)
  image=$(floci_cfg "$cloud" image)
  port=$(floci_cfg "$cloud" port)
  label=$(floci_cfg "$cloud" label)

  head1 "$label — $name on port $port"

  state=$(floci_container_state "$name")
  if [ "$state" != "absent" ]; then
    podman rm -f "$name" >/dev/null 2>&1 || true
    dim "removed the previous container (it was: $state)"
  fi

  # -v ...:z  shared SELinux relabel. Lowercase 'z', never 'Z': the socket is
  #           shared with the podman service, and an exclusive relabel breaks it.
  # FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK / FLOCI_HOSTNAME let functions that run
  #           in their own containers reach the Runtime API back on the emulator.
  #           Rootless podman's default bridge gives containers no routable IPs.
  set -- \
    -d --name "$name" \
    --network "$FLOCI_NETWORK" \
    -p "${port}:${port}" \
    -v "${SOCK}:/var/run/docker.sock:z" \
    -e "FLOCI_HOSTNAME=${name}"

  if [ "$cloud" = "aws" ]; then
    set -- "$@" -e "FLOCI_SERVICES_LAMBDA_DOCKER_NETWORK=${FLOCI_NETWORK}"
  fi

  if podman run "$@" "$image" >/dev/null; then
    ok "started"
  else
    bad "failed to start — check: podman logs $name"
    continue
  fi

  tries=0
  until curl -sS --max-time 2 -o /dev/null "http://localhost:${port}/" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 30 ]; then
      bad "port $port did not answer within 30s — check: podman logs $name"
      break
    fi
    sleep 1
  done
  if [ "$tries" -lt 30 ]; then
    ok "answering on http://localhost:${port}"
    STARTED="$STARTED $cloud"
  fi

  # The check `floci doctor` gets wrong: it stats the path on the host.
  if podman exec "$name" test -S /var/run/docker.sock 2>/dev/null; then
    ok "docker socket reachable inside the container"
  else
    bad "docker socket NOT reachable inside the container — SELinux or a bad mount"
    dim "try adding --security-opt label=disable to the podman run in libexec/up.sh"
  fi
done

if [ -z "$STARTED" ]; then
  head1 "Nothing came up."
  exit 1
fi

say ""
rule
printf '%sCONNECTION DETAILS%s\n' "$C_B" "$C_0"
rule
for cloud in $STARTED; do
  floci_print_conn "$cloud"
done

say ""
rule
dim "load into this shell:  eval \"\$(floci-podman info${STARTED} --export)\""
dim "verify:                floci-podman check"
dim "stop:                  floci-podman down"
