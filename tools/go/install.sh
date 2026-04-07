#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/usr/local"

# Fetch the latest stable Go version
echo "==> Fetching latest Go version..."
GO_VERSION="$(curl -fsSL "https://go.dev/dl/?mode=json" | grep -o '"version":"go[^"]*"' | head -1 | grep -o '[0-9][^"]*')"
if [ -z "$GO_VERSION" ]; then
  echo "Error: Could not determine latest Go version."; exit 1
fi

# Parse flags
UNINSTALL=false
for arg in "$@"; do
  case "$arg" in
    --uninstall) UNINSTALL=true ;;
    *) echo "Unknown flag: $arg"; echo "Usage: $0 [--uninstall]"; exit 1 ;;
  esac
done

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux)  OS_NAME="linux" ;;
  Darwin) OS_NAME="darwin" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64)  ARCH_NAME="amd64" ;;
  aarch64|arm64) ARCH_NAME="arm64" ;;
  *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Uninstall
if [ "$UNINSTALL" = true ]; then
  echo "==> This will remove ${INSTALL_DIR}/go and clean up your shell RC file."
  read -rp "    Are you sure? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "==> Aborted."
    exit 0
  fi

  if [ -d "${INSTALL_DIR}/go" ]; then
    echo "==> Removing ${INSTALL_DIR}/go"
    sudo rm -rf "${INSTALL_DIR}/go"
  else
    echo "==> No Go installation found at ${INSTALL_DIR}/go, skipping"
  fi

  SHELL_RC=""
  case "$SHELL" in
    */zsh)  SHELL_RC="$HOME/.zshrc" ;;
    */bash) SHELL_RC="$HOME/.bashrc" ;;
  esac

  if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
    if grep -q "/usr/local/go/bin" "$SHELL_RC"; then
      echo "==> Removing Go entries from ${SHELL_RC}"
      # Remove the Go block (comment + 3 export lines)
      sed -i.bak '/^# Go$/,/^export PATH="\$PATH:\$GOPATH\/bin"$/d' "$SHELL_RC"
      echo "==> Backup saved to ${SHELL_RC}.bak"
    else
      echo "==> No Go PATH entries found in ${SHELL_RC}, skipping"
    fi
  fi

  echo "==> Go has been uninstalled. Reload your shell to apply changes."
  exit 0
fi

TARBALL="go${GO_VERSION}.${OS_NAME}-${ARCH_NAME}.tar.gz"
URL="https://go.dev/dl/${TARBALL}"

echo "==> Installing Go ${GO_VERSION} (${OS_NAME}/${ARCH_NAME})"

# Download
echo "==> Downloading ${URL}"
curl -fLO "$URL"

# Remove any existing Go installation
if [ -d "${INSTALL_DIR}/go" ]; then
  echo "==> Removing existing Go installation at ${INSTALL_DIR}/go"
  sudo rm -rf "${INSTALL_DIR}/go"
fi

# Extract
echo "==> Extracting to ${INSTALL_DIR}"
sudo tar -C "$INSTALL_DIR" -xzf "$TARBALL"
rm "$TARBALL"

# Add to PATH if not already present
SHELL_RC=""
case "$SHELL" in
  */zsh)  SHELL_RC="$HOME/.zshrc" ;;
  */bash) SHELL_RC="$HOME/.bashrc" ;;
esac

if [ -n "$SHELL_RC" ]; then
  if ! grep -q "/usr/local/go/bin" "$SHELL_RC" 2>/dev/null; then
    echo "==> Adding Go to PATH in ${SHELL_RC}"
    {
      echo ''
      echo '# Go'
      echo 'export PATH="$PATH:/usr/local/go/bin"'
      echo 'export GOPATH="$HOME/go"'
      echo 'export PATH="$PATH:$GOPATH/bin"'
    } >> "$SHELL_RC"
    echo "==> Reload your shell or run: source ${SHELL_RC}"
  else
    echo "==> PATH already configured in ${SHELL_RC}, skipping"
  fi
fi

echo "==> Done! Go $(/usr/local/go/bin/go version) installed successfully."
