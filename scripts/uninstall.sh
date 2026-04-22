#!/usr/bin/env bash
# Reverts everything done by install.sh and leaves the system as it was.
# Can be run with:
#   curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash
set -uo pipefail

# Locate the dotfiles repo. When run via curl|bash the script has no local path,
# so fall back to the conventional location at $HOME/dotfiles.
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  DOTFILES_DIR="$HOME/dotfiles"
fi
REPO_DIR="$DOTFILES_DIR"

if [ ! -d "$DOTFILES_DIR/home" ]; then
  echo "Could not locate dotfiles repo at $DOTFILES_DIR"
  echo "Clone it first or run this script from inside the repo."
  exit 1
fi

# ── Colors ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

declare -A STEPS
declare -a STEP_ORDER

record() {
  STEPS["$1"]="${2}|${3:-}"
  STEP_ORDER+=("$1")
}

header() {
  echo ""
  echo "${C_BOLD}${C_CYAN}==> $1${C_RESET}"
}

confirm() {
  local answer
  if [ -t 0 ]; then
    read -r -p "  $1 [y/N] " answer
  else
    read -r -p "  $1 [y/N] " answer </dev/tty
  fi
  [[ "${answer,,}" == "y" ]]
}

# Try a command; record ok/fail in one go
try_remove() {
  local name="$1"; shift
  if "$@" &>/dev/null; then
    record "$name" "ok" "removed"
  else
    record "$name" "fail" "check manually"
  fi
}

# ── 1. Symlinks ───────────────────────────────────────────────────────────────
header "Removing dotfile symlinks"
removed_links=0
restored_backups=0

unlink_if_owned() {
  local src="$1" dest="$2"
  [ -L "$dest" ] || return 0
  [ "$(readlink "$dest")" = "$src" ] || return 0
  rm "$dest"
  removed_links=$((removed_links+1))
  if [ -e "${dest}.bak" ]; then
    mv "${dest}.bak" "$dest"
    restored_backups=$((restored_backups+1))
  fi
}

for src in "$DOTFILES_DIR/home"/.*; do
  [ -f "$src" ] || continue
  unlink_if_owned "$src" "$HOME/$(basename "$src")"
done
unlink_if_owned "$DOTFILES_DIR/config/aws/config" "$HOME/.aws/config"
unlink_if_owned "$DOTFILES_DIR/config/ssh/config" "$HOME/.ssh/config"
for src in "$DOTFILES_DIR/claude"/*; do
  [ -e "$src" ] || continue
  unlink_if_owned "$src" "$HOME/.claude/$(basename "$src")"
done

record "Symlinks" "ok" "$removed_links removed, $restored_backups backups restored"

# ── 2. Shell tools ────────────────────────────────────────────────────────────
header "Shell environment"
if [ -d "$HOME/.oh-my-zsh" ] && confirm "Remove Oh-My-Zsh?"; then
  rm -rf "$HOME/.oh-my-zsh"
  record "Oh-My-Zsh" "ok" "~/.oh-my-zsh"
else
  record "Oh-My-Zsh" "skip" ""
fi

[ -d "$HOME/.fzf" ] && confirm "Remove fzf?" && { "$HOME/.fzf/uninstall" &>/dev/null || true; rm -rf "$HOME/.fzf"; record "fzf" "ok" ""; } || record "fzf" "skip" ""

[ -d "$HOME/.bun" ] && confirm "Remove Bun?" && { rm -rf "$HOME/.bun"; record "Bun" "ok" ""; } || record "Bun" "skip" ""

[ -d "$HOME/.nvm" ] && confirm "Remove nvm?" && { rm -rf "$HOME/.nvm"; record "nvm" "ok" ""; } || record "nvm" "skip" ""

[ -d "$HOME/.tmux/plugins" ] && confirm "Remove tmux plugins (TPM)?" && { rm -rf "$HOME/.tmux"; record "TPM" "ok" ""; } || record "TPM" "skip" ""

# ── 3. Binaries in /usr/local/bin ─────────────────────────────────────────────
header "Kubernetes & cloud tools"
for bin in kubectl kubectx kubens minikube helm k9s stern kustomize argocd terraform session-manager-plugin; do
  if command -v "$bin" &>/dev/null && confirm "Remove $bin?"; then
    sudo rm -f "/usr/local/bin/$bin" "/usr/bin/$bin" 2>/dev/null
    [ "$bin" = "kubectx" ] && sudo rm -rf /opt/kubectx
    record "$bin" "ok" ""
  else
    record "$bin" "skip" ""
  fi
done

if command -v aws &>/dev/null && confirm "Remove AWS CLI v2?"; then
  sudo rm -rf /usr/local/aws-cli
  sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer
  record "AWS CLI" "ok" ""
else
  record "AWS CLI" "skip" ""
fi

# ── 4. Terminal productivity ──────────────────────────────────────────────────
header "Terminal productivity tools"
for pkg in zoxide atuin bat eza delta direnv jq gh openvpn docker docker-compose-plugin python3-pip pipx; do
  if command -v "${pkg%-*}" &>/dev/null && confirm "Remove $pkg?"; then
    sudo apt-get remove -y -qq "$pkg" &>/dev/null || rm -rf "$HOME/.$pkg" 2>/dev/null
    record "$pkg" "ok" ""
  else
    record "$pkg" "skip" ""
  fi
done

# ── 5. Editors ────────────────────────────────────────────────────────────────
header "Editors"
command -v code &>/dev/null && confirm "Remove VS Code?" && { sudo apt-get remove -y -qq code &>/dev/null; record "VS Code" "ok" ""; } || record "VS Code" "skip" ""
command -v cursor &>/dev/null && confirm "Remove Cursor?" && { sudo rm -f /usr/local/bin/cursor; record "Cursor" "ok" ""; } || record "Cursor" "skip" ""

# ── 6. Nerd Fonts ─────────────────────────────────────────────────────────────
if fc-list 2>/dev/null | grep -qi "JetBrainsMono" && confirm "Remove Nerd Fonts?"; then
  rm -f "$HOME/.local/share/fonts"/JetBrainsMono*.ttf 2>/dev/null
  fc-cache -f &>/dev/null
  record "Nerd Fonts" "ok" "JetBrainsMono"
else
  record "Nerd Fonts" "skip" ""
fi

# ── 7. Ring (Claude marketplace) ──────────────────────────────────────────────
if command -v claude &>/dev/null && confirm "Uninstall Ring marketplace plugins?"; then
  claude plugin marketplace remove lerianstudio/ring &>/dev/null || true
  rm -rf "$HOME/.claude/plugins/marketplaces/lerianstudio-ring" 2>/dev/null
  record "Ring" "ok" "marketplace removed"
else
  record "Ring" "skip" ""
fi

if command -v claude &>/dev/null && confirm "Uninstall Claude Code CLI?"; then
  npm uninstall -g @anthropic-ai/claude-code &>/dev/null || \
  bun uninstall -g @anthropic-ai/claude-code &>/dev/null || true
  record "Claude CLI" "ok" ""
else
  record "Claude CLI" "skip" ""
fi

# ── 8. Default shell back to bash ─────────────────────────────────────────────
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" = "$(command -v zsh)" ] && confirm "Restore default shell to bash?"; then
  sudo chsh -s "$(command -v bash)" "$USER" && record "Default shell" "ok" "reset to bash" || record "Default shell" "fail" "run manually"
else
  record "Default shell" "skip" ""
fi

# ── 9. Repo itself ────────────────────────────────────────────────────────────
if confirm "Remove the dotfiles repo ($REPO_DIR)?"; then
  # Can't delete cwd safely if script runs from inside
  cd /tmp
  rm -rf "$REPO_DIR"
  record "Repo" "ok" "$REPO_DIR deleted"
else
  record "Repo" "skip" "$REPO_DIR kept"
fi

# ── 10. Summary ───────────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
echo "${C_BOLD}${C_CYAN}║                        Uninstall Summary                          ║${C_RESET}"
echo "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"
echo ""
printf "  %-22s %-8s %s\n" "STEP" "STATUS" "DETAIL"
printf "  %-22s %-8s %s\n" "────" "──────" "──────"
for name in "${STEP_ORDER[@]}"; do
  IFS='|' read -r status detail <<< "${STEPS[$name]}"
  case "$status" in
    ok)   icon="${C_GREEN}✓ ok${C_RESET}   " ;;
    skip) icon="${C_DIM}○ skip${C_RESET} " ;;
    fail) icon="${C_RED}✗ fail${C_RESET} " ;;
  esac
  printf "  %-22s %b %s\n" "$name" "$icon" "${C_DIM}${detail}${C_RESET}"
done

echo ""
echo "${C_BOLD}${C_YELLOW}Notes:${C_RESET}"
echo "  • APT packages were removed but ${C_CYAN}sudo apt-get autoremove${C_RESET} may clean leftover deps"
echo "  • Data in ~/.aws, ~/.kube, ~/.ssh (keys, configs) was NOT touched"
echo "  • Log out and back in to return to the previous shell"
echo ""
