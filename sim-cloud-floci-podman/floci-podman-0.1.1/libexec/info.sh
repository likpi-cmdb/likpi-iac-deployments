# floci-podman info — print connection details without touching containers.

_info_usage() {
  cat <<USAGE
${C_B}floci-podman info${C_0} — print connection details

  floci-podman info [cloud ...] [--export]

  --export   print bare export lines only, for:
             eval "\$(floci-podman info aws --export)"
USAGE
}

EXPORT=0
ARGS=""
for _a in "$@"; do
  case "$_a" in
    --export|-e) EXPORT=1 ;;
    -h|--help) _info_usage; return 0 2>/dev/null || exit 0 ;;
    *) ARGS="$ARGS $_a" ;;
  esac
done

# shellcheck disable=SC2086
CLOUDS=$(floci_pick_clouds $ARGS) || exit 1

if [ "$EXPORT" -eq 1 ]; then
  for cloud in $CLOUDS; do
    floci_conn_exports "$cloud"
  done
  exit 0
fi

for cloud in $CLOUDS; do
  name=$(floci_cfg "$cloud" name)
  floci_print_conn "$cloud"
  if command -v podman >/dev/null 2>&1; then
    state=$(floci_container_state "$name")
    if [ "$state" != "running" ]; then
      warn "container $name is not running (state: $state) — floci-podman up $cloud"
    fi
  fi
done
say ""
