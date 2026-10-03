# bash completion for floci-podman
_floci_podman() {
  local cur prev cmds clouds
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  cmds="up down check info help version"
  clouds="aws az gcp oci"

  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$cmds --help --version" -- "$cur"))
    return
  fi

  case "${COMP_WORDS[1]}" in
    up|check)  COMPREPLY=($(compgen -W "$clouds --help" -- "$cur")) ;;
    down)      COMPREPLY=($(compgen -W "$clouds --purge --help" -- "$cur")) ;;
    info)      COMPREPLY=($(compgen -W "$clouds --export --help" -- "$cur")) ;;
    *)         COMPREPLY=() ;;
  esac
}
complete -F _floci_podman floci-podman
