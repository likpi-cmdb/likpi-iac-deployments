# floci-podman down — stop and remove emulator containers.

_down_usage() {
  cat <<USAGE
${C_B}floci-podman down${C_0} — stop and remove Floci emulator containers

  floci-podman down [cloud ...] [--purge]

  --purge   also remove the ${FLOCI_NETWORK} network
USAGE
}

PURGE=0
ARGS=""
for _a in "$@"; do
  case "$_a" in
    --purge) PURGE=1 ;;
    -h|--help) _down_usage; return 0 2>/dev/null || exit 0 ;;
    *) ARGS="$ARGS $_a" ;;
  esac
done

# shellcheck disable=SC2086
CLOUDS=$(floci_pick_clouds $ARGS) || exit 1
floci_require_podman || exit 1

head1 "Stopping"
for cloud in $CLOUDS; do
  name=$(floci_cfg "$cloud" name)
  state=$(floci_container_state "$name")
  if [ "$state" = "absent" ]; then
    dim "$name — no such container"
    continue
  fi
  if podman rm -f "$name" >/dev/null 2>&1; then
    ok "$name removed (was: $state)"
  else
    bad "$name — could not remove"
  fi
done

if [ "$PURGE" -eq 1 ]; then
  if podman network exists "$FLOCI_NETWORK" 2>/dev/null; then
    if podman network rm "$FLOCI_NETWORK" >/dev/null 2>&1; then
      ok "network $FLOCI_NETWORK removed"
    else
      warn "network $FLOCI_NETWORK is still in use by other containers — leaving it"
    fi
  fi
fi
