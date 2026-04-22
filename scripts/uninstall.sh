#!/usr/bin/env bash
# Reverts everything done by install.sh and leaves the system as it was.
# Can be run with:
#   curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/uninstall.sh | bash
set -uo pipefail

if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
else
  DOTFILES_DIR="$HOME/dotfiles"
fi
REPO_DIR="$DOTFILES_DIR"

if [ ! -d "$DOTFILES_DIR/home" ]; then
  echo "Could not locate dotfiles repo at $DOTFILES_DIR"
  exit 1
fi

AUTO_YES=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) AUTO_YES=1 ;;
    -h|--help) echo "Usage: uninstall.sh [-y|--yes]"; exit 0 ;;
  esac
done

if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

declare -A CATEGORIES
declare -a CATEGORY_ORDER=("Symlinks" "Shell" "Kubernetes" "Cloud" "Dev" "Terminal" "Editors" "Claude" "System")

track() {
  local category="$1" tool="$2" status="$3"
  CATEGORIES["$category"]+="${tool}:${status}|"
}

header() { echo ""; echo "${C_BOLD}${C_CYAN}==> $1${C_RESET}"; }

confirm() {
  local answer
  if [ "$AUTO_YES" -eq 1 ]; then
    echo "  $1 [Y/n] ${C_DIM}(auto-yes)${C_RESET}"
    return 0
  fi
  if [ -t 0 ]; then
    read -r -p "  $1 [Y/n] " answer
  else
    read -r -p "  $1 [Y/n] " answer </dev/tty
  fi
  [[ "${answer,,}" != "n" ]]
}

# remove_tool <category> <name> <check-cmd> <removal-block>
remove_tool() {
  local category="$1" name="$2" check="$3" remove_cmd="$4"
  if ! eval "$check" &>/dev/null; then
    track "$category" "$name" "absent"
    return 0
  fi
  if [ "$INDIVIDUAL_MODE" = "1" ] && ! confirm "    - Remove $name?"; then
    track "$category" "$name" "kept"
    return 0
  fi
  echo "  Removing $name"
  if eval "$remove_cmd" &>/dev/null; then
    track "$category" "$name" "removed"
  else
    track "$category" "$name" "failed"
  fi
}

# Ask per-category whether to proceed, and if so ask if user wants to pick individually
start_category() {
  local label="$1"
  INDIVIDUAL_MODE=0
  CATEGORY_ACTIVE=0
  if confirm "• $label?"; then
    CATEGORY_ACTIVE=1
    if [ "$AUTO_YES" -ne 1 ]; then
      confirm "    Pick tools individually? (otherwise remove all)" && INDIVIDUAL_MODE=1
    fi
  fi
}

# ── 1. Symlinks ───────────────────────────────────────────────────────────────
header "What do you want to remove?"

start_category "Dotfile symlinks"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  unlink_if_owned() {
    local src="$1" dest="$2" name="$3"
    if [ ! -L "$dest" ] || [ "$(readlink "$dest")" != "$src" ]; then
      track "Symlinks" "$name" "absent"
      return 0
    fi
    if [ "$INDIVIDUAL_MODE" = "1" ] && ! confirm "    - Unlink $name?"; then
      track "Symlinks" "$name" "kept"
      return 0
    fi
    rm "$dest"
    [ -e "${dest}.bak" ] && mv "${dest}.bak" "$dest"
    track "Symlinks" "$name" "removed"
  }
  for src in "$DOTFILES_DIR/home"/.*; do
    [ -f "$src" ] || continue
    n="$(basename "$src")"
    unlink_if_owned "$src" "$HOME/$n" "$n"
  done
  unlink_if_owned "$DOTFILES_DIR/config/aws/config" "$HOME/.aws/config" ".aws/config"
  unlink_if_owned "$DOTFILES_DIR/config/ssh/config" "$HOME/.ssh/config" ".ssh/config"
  for src in "$DOTFILES_DIR/claude"/*; do
    [ -e "$src" ] || continue
    n="$(basename "$src")"
    unlink_if_owned "$src" "$HOME/.claude/$n" ".claude/$n"
  done
fi

# ── 2. Shell ──────────────────────────────────────────────────────────────────
start_category "Shell tools (oh-my-zsh, fzf, tmux plugins, fonts)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  remove_tool "Shell" "oh-my-zsh" '[ -d "$HOME/.oh-my-zsh" ]' 'rm -rf "$HOME/.oh-my-zsh"'
  remove_tool "Shell" "fzf" '[ -d "$HOME/.fzf" ]' '"$HOME/.fzf/uninstall" &>/dev/null; rm -rf "$HOME/.fzf"'
  remove_tool "Shell" "tmux-tpm" '[ -d "$HOME/.tmux/plugins" ]' 'rm -rf "$HOME/.tmux"'
  remove_tool "Shell" "JetBrainsMono Nerd Font" 'fc-list | grep -qi JetBrainsMono' 'rm -f "$HOME/.local/share/fonts"/JetBrainsMono*.ttf && fc-cache -f'
fi

# ── 3. Kubernetes ─────────────────────────────────────────────────────────────
start_category "Kubernetes (kubectl, helm, k9s, stern, kustomize, argocd, minikube)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  for bin in kubectl minikube helm k9s stern kustomize argocd; do
    remove_tool "Kubernetes" "$bin" "command -v $bin" "sudo rm -f /usr/local/bin/$bin /usr/bin/$bin"
  done
  remove_tool "Kubernetes" "kubectx/kubens" 'command -v kubectx' 'sudo rm -f /usr/local/bin/kubectx /usr/local/bin/kubens && sudo rm -rf /opt/kubectx'
fi

# ── 4. Cloud ──────────────────────────────────────────────────────────────────
start_category "Cloud (aws-cli, ssm, terraform, openvpn)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  remove_tool "Cloud" "aws-cli" 'command -v aws' 'sudo rm -rf /usr/local/aws-cli && sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer'
  remove_tool "Cloud" "ssm-plugin" 'command -v session-manager-plugin' 'sudo apt-get remove -y -qq session-manager-plugin'
  remove_tool "Cloud" "terraform" 'command -v terraform' 'sudo rm -f /usr/local/bin/terraform'
  remove_tool "Cloud" "openvpn" 'command -v openvpn' 'sudo apt-get remove -y -qq openvpn'
fi

# ── 5. Dev ────────────────────────────────────────────────────────────────────
start_category "Dev (docker, python, bun, gh, claude-cli)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  remove_tool "Dev" "docker" 'command -v docker' 'sudo apt-get remove -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
  remove_tool "Dev" "python3-pip" 'command -v pip3' 'sudo apt-get remove -y -qq python3-pip'
  remove_tool "Dev" "pipx" 'command -v pipx' 'sudo apt-get remove -y -qq pipx'
  remove_tool "Dev" "bun" '[ -d "$HOME/.bun" ]' 'rm -rf "$HOME/.bun"'
  remove_tool "Dev" "gh" 'command -v gh' 'sudo apt-get remove -y -qq gh'
  remove_tool "Dev" "claude-cli" 'command -v claude' 'npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || bun uninstall -g @anthropic-ai/claude-code'
fi

# ── 6. Terminal ───────────────────────────────────────────────────────────────
start_category "Terminal (zoxide, bat, eza, delta, atuin, direnv, jq)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  remove_tool "Terminal" "zoxide" 'command -v zoxide' 'rm -f "$HOME/.local/bin/zoxide"'
  remove_tool "Terminal" "bat" 'command -v bat' 'sudo apt-get remove -y -qq bat'
  remove_tool "Terminal" "eza" 'command -v eza' 'sudo apt-get remove -y -qq eza'
  remove_tool "Terminal" "delta" 'command -v delta' 'sudo apt-get remove -y -qq git-delta'
  remove_tool "Terminal" "atuin" 'command -v atuin' '
    # Remove binary wherever it lives
    atuin_path="$(command -v atuin 2>/dev/null)"
    [ -n "$atuin_path" ] && sudo rm -f "$atuin_path"
    # Clean up install dirs and data
    rm -rf "$HOME/.atuin" "$HOME/.local/share/atuin" "$HOME/.config/atuin"
    rm -f "$HOME/.local/bin/atuin" "$HOME/.cargo/bin/atuin"
    # Try uninstalling via package managers if installed that way
    sudo apt-get remove -y -qq atuin 2>/dev/null || true
    # Verify
    ! command -v atuin &>/dev/null
  '
  remove_tool "Terminal" "direnv" 'command -v direnv' 'sudo apt-get remove -y -qq direnv || rm -f "$HOME/.local/bin/direnv"'
  remove_tool "Terminal" "jq" 'command -v jq' 'sudo apt-get remove -y -qq jq'
fi

# ── 7. Editors ────────────────────────────────────────────────────────────────
start_category "Editors (vscode, cursor)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  remove_tool "Editors" "vscode" 'command -v code' 'sudo apt-get remove -y -qq code'
  remove_tool "Editors" "cursor" 'command -v cursor' 'sudo rm -f /usr/local/bin/cursor'
fi

# ── 8. Claude ─────────────────────────────────────────────────────────────────
start_category "Claude (Ring marketplace)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  remove_tool "Claude" "Ring marketplace" '[ -d "$HOME/.claude/plugins/marketplaces/lerianstudio-ring" ] || command -v claude' 'claude plugin marketplace remove lerianstudio/ring &>/dev/null; rm -rf "$HOME/.claude/plugins/marketplaces/lerianstudio-ring"'
fi

# ── 9. System ─────────────────────────────────────────────────────────────────
start_category "System (default shell, repo directory)"
if [ "$CATEGORY_ACTIVE" = "1" ]; then
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [ "$current_shell" = "$(command -v zsh)" ]; then
    if [ "$INDIVIDUAL_MODE" != "1" ] || confirm "    - Restore default shell to bash?"; then
      sudo chsh -s "$(command -v bash)" "$USER" && track "System" "default shell → bash" "removed" || track "System" "default shell → bash" "failed"
    else
      track "System" "default shell" "kept"
    fi
  else
    track "System" "default shell" "absent"
  fi
  if [ -d "$REPO_DIR" ]; then
    if [ "$INDIVIDUAL_MODE" != "1" ] || confirm "    - Remove repo ($REPO_DIR)?"; then
      cd /tmp && rm -rf "$REPO_DIR" && track "System" "repo" "removed"
    else
      track "System" "repo" "kept"
    fi
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
echo "${C_BOLD}${C_CYAN}║                        Removed Items                              ║${C_RESET}"
echo "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"

any_output=0
for cat in "${CATEGORY_ORDER[@]}"; do
  entries="${CATEGORIES[$cat]:-}"
  [ -z "$entries" ] && continue
  any_output=1
  echo ""
  echo "  ${C_BOLD}${C_YELLOW}▸ $cat${C_RESET}"
  IFS='|' read -ra items <<< "$entries"
  for item in "${items[@]}"; do
    [ -z "$item" ] && continue
    name="${item%:*}"; status="${item##*:}"
    case "$status" in
      removed) icon="${C_GREEN}- removed${C_RESET}  " ;;
      kept)    icon="${C_DIM}○ kept   ${C_RESET}  " ;;
      absent)  icon="${C_DIM}~ absent ${C_RESET}  " ;;
      failed)  icon="${C_RED}✗ failed ${C_RESET}  " ;;
    esac
    printf "      %b %s\n" "$icon" "$name"
  done
done

[ "$any_output" = "0" ] && echo "  ${C_DIM}(nothing processed)${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}Notes:${C_RESET}"
echo "  • Data in ~/.aws, ~/.kube, ~/.ssh (keys, configs) was NOT touched"
echo "  • Run ${C_CYAN}sudo apt-get autoremove${C_RESET} to clean leftover deps"
echo "  • Log out and back in for shell change to take effect"
echo ""
