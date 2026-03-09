#!/bin/bash
# Docker Full Uninstall Script for macOS
# Run with: bash uninstall_macos.sh
# Use DRY_RUN=1 bash uninstall_macos.sh to preview without deleting

# Author: Johnny Mayo (johnnymayodev on github)
# Date: 2026-03-09
# Version: 1.0.0

DRY_RUN=${DRY_RUN:-0}
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

safe_remove() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      echo -e "  ${YELLOW}[DRY RUN]${NC} Would remove: $path"
    else
      echo -e "  ${RED}Removing:${NC} $path"
      sudo rm -rf "$path"
    fi
  fi
}

section() {
  echo ""
  echo -e "${GREEN}==> $1${NC}"
}

docker_running() {
  docker info > /dev/null 2>&1
}

echo "=============================="
echo " Docker macOS Uninstall Script"
[ "$DRY_RUN" = "1" ] && echo -e " ${YELLOW}DRY RUN MODE - nothing will be deleted${NC}"
echo "=============================="

# --- Stop all running containers ---
section "Stopping all running containers"
if docker_running; then
  RUNNING=$(docker ps -q 2>/dev/null)
  if [ -n "$RUNNING" ]; then
    if [ "$DRY_RUN" = "1" ]; then
      echo -e "  ${YELLOW}[DRY RUN]${NC} Would stop the following containers:"
      docker ps --format "    - {{.Names}} ({{.ID}})"
    else
      echo -e "  ${RED}Stopping all running containers...${NC}"
      docker stop $(docker ps -q)
      echo "  Done."
    fi
  else
    echo "  No running containers found."
  fi
else
  echo "  Docker daemon not reachable — skipping container stop."
fi

# --- Docker system prune ---
section "Pruning all Docker resources"
if docker_running; then
  if [ "$DRY_RUN" = "1" ]; then
    echo -e "  ${YELLOW}[DRY RUN]${NC} Would run: docker system prune -af --volumes"
    echo -e "  ${YELLOW}[DRY RUN]${NC} Would run: docker builder prune -af"
    echo -e "  ${YELLOW}[DRY RUN]${NC} Would run: docker network prune -f"
  else
    echo -e "  ${RED}Removing all containers, images, volumes, and build cache...${NC}"
    docker system prune -af --volumes
    echo -e "  ${RED}Removing all build cache...${NC}"
    docker builder prune -af
    echo -e "  ${RED}Removing all unused networks...${NC}"
    docker network prune -f
    echo "  Done."
  fi
else
  echo "  Docker daemon not reachable — skipping prune."
fi

# --- Prompt user to uninstall Docker Desktop ---
section "Uninstall Docker Desktop"
echo ""
echo -e "${BOLD}${CYAN}Before this script removes Docker's files, you should uninstall"
echo -e "Docker Desktop itself. Choose one of the following methods:${NC}"
echo ""
echo -e "  ${BOLD}Option A — Native GUI (recommended):${NC}"
echo "    1. Open Docker Desktop"
echo "    2. Click the bug/troubleshoot icon (top-right of the dashboard)"
echo "    3. Click 'Uninstall' and confirm"
echo "    4. Move Docker.app to Trash when prompted"
echo ""
echo -e "  ${BOLD}Option B — CLI uninstall:${NC}"
echo "    Run the following command in your terminal:"
echo ""
echo -e "    ${CYAN}/Applications/Docker.app/Contents/MacOS/uninstall${NC}"
echo ""
echo -e "  ${YELLOW}Note:${NC} You may see an 'operation not permitted' error during the CLI"
echo "  uninstall — this can be safely ignored. Docker will still be uninstalled."
echo "  If needed, grant Full Disk Access to your terminal app via:"
echo "  System Settings > Privacy & Security > Full Disk Access"
echo ""

read -rp "  Have you uninstalled Docker Desktop? Continue with file cleanup? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo ""
  echo -e "  ${YELLOW}Aborted.${NC} Re-run this script after uninstalling Docker Desktop."
  exit 0
fi

# --- Stop & remove launchctl services ---
section "Stopping Docker services"
for service in $(launchctl list | grep docker | awk '{print $3}'); do
  if [ "$DRY_RUN" = "1" ]; then
    echo -e "  ${YELLOW}[DRY RUN]${NC} Would remove launchctl service: $service"
  else
    echo -e "  ${RED}Removing launchctl service:${NC} $service"
    launchctl remove "$service"
  fi
done

# --- Kill any remaining Docker processes ---
section "Killing Docker processes"
if pgrep -x "Docker" > /dev/null; then
  if [ "$DRY_RUN" = "1" ]; then
    echo -e "  ${YELLOW}[DRY RUN]${NC} Would kill Docker process"
  else
    echo -e "  ${RED}Killing Docker process${NC}"
    pkill -x "Docker"
    sleep 2
  fi
else
  echo "  No running Docker processes found."
fi

# --- Remove app bundle ---
section "Removing Docker.app"
safe_remove "/Applications/Docker.app"

# --- Remove binaries ---
section "Removing Docker binaries"
for bin in docker docker-compose docker-credential-desktop docker-credential-osxkeychain docker-credential-ecr-login; do
  safe_remove "/usr/local/bin/$bin"
  safe_remove "/opt/homebrew/bin/$bin"
done

# --- Remove CLI plugins ---
section "Removing Docker CLI plugins"
safe_remove "/usr/local/lib/docker"
safe_remove "$HOME/.docker/cli-plugins"

# --- Remove plist files ---
section "Removing LaunchAgent/LaunchDaemon plists"
for dir in \
  "$HOME/Library/LaunchAgents" \
  "/Library/LaunchAgents" \
  "/Library/LaunchDaemons" \
  "/Library/PrivilegedHelperTools"
do
  for f in $(find "$dir" -name "*docker*" 2>/dev/null); do
    safe_remove "$f"
  done
done

# --- Remove user data & config ---
section "Removing Docker user data and config"
safe_remove "$HOME/.docker"
safe_remove "$HOME/Library/Application Support/Docker Desktop"
safe_remove "$HOME/Library/Preferences/com.docker.docker.plist"
safe_remove "$HOME/Library/Preferences/com.electron.docker-frontend.plist"
safe_remove "$HOME/Library/Saved Application State/com.electron.docker-frontend.savedState"
safe_remove "$HOME/Library/Logs/Docker Desktop"
safe_remove "$HOME/Library/Cookies/com.docker.docker.binarycookies"
safe_remove "$HOME/Library/HTTPStorages/com.docker.docker"
safe_remove "$HOME/Library/Group Containers/group.com.docker"
# Residual files per official Docker docs
safe_remove "$HOME/Library/Containers/com.docker.docker"
safe_remove "/Library/PrivilegedHelperTools/com.docker.vmnetd"
safe_remove "/Library/PrivilegedHelperTools/com.docker.socket"

# --- Remove completion files ---
section "Removing Zsh completion files"
for f in $(find /usr/local/share/zsh /opt/homebrew/share/zsh -name "*docker*" 2>/dev/null); do
  safe_remove "$f"
done

# --- Rebuild zsh completion cache ---
section "Rebuilding Zsh completion cache"
if [ "$DRY_RUN" = "1" ]; then
  echo -e "  ${YELLOW}[DRY RUN]${NC} Would rebuild Zsh completion cache"
else
  rm -f "$HOME/.zcompdump"
  echo "  Done."
fi

# --- Final check ---
section "Verification"
remaining=$(find /usr/local/bin /opt/homebrew/bin /Applications 2>/dev/null \
  -name "*docker*" -o -name "*Docker*" 2>/dev/null | grep -v ".Trash")
if [ -z "$remaining" ]; then
  echo -e "  ${GREEN}No Docker files found in common locations. Looks clean!${NC}"
else
  echo -e "  ${YELLOW}Some files may still remain:${NC}"
  echo "$remaining"
fi

echo ""
echo "=============================="
echo -e " ${GREEN}Done!${NC} Run 'exec zsh' to reload your shell."
echo "=============================="