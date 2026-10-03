#!/usr/bin/env zsh

# Variables
REPO_URL="https://github.com/DawidAdamski/floci-podman"
VERSION="0.1.1"
ARCHIVE_URL="https://github.com/DawidAdamski/floci-podman/archive/refs/tags/v${VERSION}.tar.gz"
SHA256="553307fcd23a68c0ac1197ec6daa8101b2232fd9f049f652e268535fa3b580b5"
INSTALL_PREFIX="./"
BIN_DIR="$INSTALL_PREFIX/bin"
LIBEXEC_DIR="$INSTALL_PREFIX/libexec/floci-podman"
COMPLETIONS_DIR="$INSTALL_PREFIX/share/zsh/site-functions"
DOC_DIR="$INSTALL_PREFIX/share/doc/floci-podman"
TEMP_DIR="$INSTALL_PREFIX/tmp"
SRC_DIR="$TEMP_DIR/floci-podman-0.1.1"
# Persistent cache so the archive is not re-downloaded on each run
#CACHE_DIR="${XDG_CACHE_HOME:-./.cache}/floci-podman"
CACHE_DIR="./.cache/"
ARCHIVE="$CACHE_DIR/floci-podman-v${VERSION}.tar.gz"

set -euo pipefail

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT INT TERM
SRC_DIR="$TEMP_DIR/floci-podman-${VERSION}"

# Create directories
mkdir -p -- "$LIBEXEC_DIR/bin" "$BIN_DIR" "$COMPLETIONS_DIR" "$DOC_DIR" "$TEMP_DIR" "$SRC_DIR" "$CACHE_DIR"

# Use the cached archive if present and valid; download otherwise
verify_sha256() {
    echo "$SHA256  $1" | sha256sum -c - >/dev/null 2>&1
}

if [[ -f $ARCHIVE ]] && verify_sha256 "$ARCHIVE"; then
    echo "Using cached archive: $ARCHIVE"
else
    echo "Downloading floci-podman..."
    curl -fsSL "$ARCHIVE_URL" -o "$TEMP_DIR/floci-podman-v${VERSION}.tar.gz" || {
        echo "Failed to download the archive." >&2
        exit 1
    }
    if ! verify_sha256 "$TEMP_DIR/floci-podman.tar.gz"; then
        echo "SHA256 verification failed." >&2
        exit 1
    fi
    mv -f -- "$TEMP_DIR/floci-podman-v${VERSION}.tar.gz" "$ARCHIVE"
fi

# Scope the extraction: every member must live under a single root dir,
# with no absolute paths or ".." traversal, before tar touches the disk
TAR_ROOT="$(tar -tzf "$ARCHIVE" | head -n 1 | cut -d/ -f1)"
if [[ -z $TAR_ROOT || $TAR_ROOT == .* || $TAR_ROOT == */ || $TAR_ROOT == .. ]]; then
    echo "Archive has an unsafe or unexpected layout." >&2
    exit 1
fi

tar -tzf "$ARCHIVE" | while IFS= read -r member; do
    case $member in
        "$TAR_ROOT"/*|"$TAR_ROOT"/) ;;
        *) echo "Refusing unsafe archive member: $member" >&2; exit 1 ;;
    esac
done
SRC_DIR="$TEMP_DIR/$TAR_ROOT"
if [[ ! -d $SRC_DIR ]]; then
    echo "Could not find extracted source directory." >&2
    exit 1
fi

SRC_DIR="$TEMP_DIR/$TAR_ROOT"
if [[ ! -d $SRC_DIR ]]; then
    echo "Could not find extracted source directory." >&2
    exit 1
fi

# Install files
echo "Installing floci-podman..."
if [[ ! -d $SRC_DIR/lib || ! -f $SRC_DIR/libexec/floci-podman ]]; then
    echo "Unexpected archive layout (missing lib/ or libexec/floci-podman in $SRC_DIR)." >&2
    exit 1
fi
cp -rp -- "$SRC_DIR"/lib/* "$LIBEXEC_DIR/"
cp -p -- "$SRC_DIR/libexec/floci-podman" "$LIBEXEC_DIR/bin/"
cp -p -- "$SRC_DIR/completions/_floci-podman" "$COMPLETIONS_DIR/_floci-podman"
cp -p -- "$SRC_DIR/README.md" "$DOC_DIR/"
cp -p -- "$SRC_DIR/CHANGELOG.md" "$DOC_DIR/"

# Symlink the binary
ln -sf -- "$LIBEXEC_DIR/bin/floci-podman" "$BIN_DIR/floci-podman"

# Cleanup
# rm -rf -- "$SRC_DIR"

# Print caveats
echo ""
echo "Installation complete!"
echo "Caveats:"
echo "  - floci-podman replaces 'floci start' and 'floci stop' only."
echo "  - The rest of the floci CLI (logs, services, snapshot, env) remains unchanged."
echo "  - Requires a running podman machine. Start it with:"
echo "      podman machine start"
echo "  - Then run:"
echo "      floci-podman up"