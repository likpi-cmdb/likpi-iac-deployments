#!/bin/bash

# https://github.com/DawidAdamski/homebrew-floci-podman/blob/main/Formula/floci-podman.rb
# Variables
REPO_URL="https://github.com/DawidAdamski/floci-podman"
ARCHIVE_URL="https://github.com/DawidAdamski/floci-podman/archive/refs/tags/v0.1.1.tar.gz"
SHA256="553307fcd23a68c0ac1197ec6daa8101b2232fd9f049f652e268535fa3b580b5"
# INSTALL_PREFIX="/usr/local"
INSTALL_PREFIX="$(pwd)"
BIN_DIR="./bin"
LIBEXEC_DIR="./libexec/floci-podman"
COMPLETIONS_DIR="./etc/bash_completion.d"
ZSH_COMPLETIONS_DIR="./share/zsh/site-functions"
DOC_DIR="./share/doc/floci-podman"

# Create directories
mkdir -p "$LIBEXEC_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$COMPLETIONS_DIR"
mkdir -p "$ZSH_COMPLETIONS_DIR"
mkdir -p "$DOC_DIR"

# Download and extract the archive
echo "Downloading floci-podman..."
curl -L "$ARCHIVE_URL" -o /tmp/floci-podman.tar.gz
echo "Verifying SHA256..."
echo "$SHA256  /tmp/floci-podman.tar.gz" | sha256sum -c -
tar -xzf /tmp/floci-podman.tar.gz -C /tmp
rm /tmp/floci-podman.tar.gz

# Install files
echo "Installing floci-podman..."
cp -r /tmp/floci-podman-0.1.1/lib "$LIBEXEC_DIR/"
cp /tmp/floci-podman-0.1.1/libexec/floci-podman "$LIBEXEC_DIR/bin/"
cp /tmp/floci-podman-0.1.1/completions/floci-podman.bash "$COMPLETIONS_DIR/floci-podman"
cp /tmp/floci-podman-0.1.1/completions/_floci-podman "$ZSH_COMPLETIONS_DIR/_floci-podman"
cp /tmp/floci-podman-0.1.1/README.md "$DOC_DIR/"
cp /tmp/floci-podman-0.1.1/CHANGELOG.md "$DOC_DIR/"

# Symlink the binary
ln -sf "$LIBEXEC_DIR/bin/floci-podman" "$BIN_DIR/floci-podman"

# Cleanup
rm -rf /tmp/floci-podman-0.1.1

echo "Installation complete!"
echo "Caveats:"
echo "  - floci-podman replaces 'floci start' and 'floci stop' only."
echo "  - The rest of the floci CLI (logs, services, snapshot, env) remains unchanged."
echo "  - Requires a running podman machine. Start it with:"
echo "    podman machine start"
echo "  - Then run:"
echo "    floci-podman up"