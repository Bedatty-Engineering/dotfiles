#!/usr/bin/env bash
# Update dotfiles to the latest version from remote.
# Can be run with:
#   curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/update.sh | bash
set -euo pipefail

REPO_DIR="$HOME/dotfiles"

AUTO_YES=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) AUTO_YES=1 ;;
    -h|--help) echo "Usage: update.sh [-y|--yes]"; exit 0 ;;
  esac
done

if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

ask() {
  local msg="$1" default="${2:-y}" answer
  local prompt="[Y/n]"
  [ "$default" = "n" ] && prompt="[y/N]"
  if [ "$AUTO_YES" -eq 1 ]; then
    echo "  $msg $prompt ${C_DIM}(auto-yes)${C_RESET}"
    return 0
  fi
  if [ -t 0 ]; then
    read -r -p "  $msg $prompt " answer
  else
    read -r -p "  $msg $prompt " answer </dev/tty
  fi
  answer="${answer,,}"
  if [ "$default" = "n" ]; then
    [[ "$answer" == "y" ]]
  else
    [[ "$answer" != "n" ]]
  fi
}

header() { echo ""; echo "${C_BOLD}${C_CYAN}==> $1${C_RESET}"; }

# ── Verify repo exists ────────────────────────────────────────────────────────
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "${C_RED}✗${C_RESET} $REPO_DIR is not a git repo."
  echo "  Run install.sh first:"
  echo "      ${C_CYAN}curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash${C_RESET}"
  exit 1
fi

# ── Fetch + log changes ───────────────────────────────────────────────────────
header "Fetching remote changes"
GIT="GIT_CONFIG_GLOBAL=/dev/null git -C $REPO_DIR"
eval "$GIT fetch --quiet origin"

LOCAL_HEAD="$(git -C "$REPO_DIR" rev-parse HEAD)"
REMOTE_HEAD="$(git -C "$REPO_DIR" rev-parse '@{u}' 2>/dev/null || git -C "$REPO_DIR" rev-parse origin/main)"

if [ "$LOCAL_HEAD" = "$REMOTE_HEAD" ]; then
  echo "  ${C_GREEN}✓${C_RESET} Already up to date (${C_DIM}${LOCAL_HEAD:0:7}${C_RESET})"
  exit 0
fi

COMMITS_AHEAD="$(git -C "$REPO_DIR" rev-list --count "$LOCAL_HEAD..$REMOTE_HEAD")"
echo "  ${C_YELLOW}$COMMITS_AHEAD new commit(s):${C_RESET}"
git -C "$REPO_DIR" log --oneline --decorate --color=always "$LOCAL_HEAD..$REMOTE_HEAD" | sed 's/^/    /'

# ── Check for changed categories to hint re-install ──────────────────────────
CHANGED_FILES="$(git -C "$REPO_DIR" diff --name-only "$LOCAL_HEAD..$REMOTE_HEAD")"
PACKAGES_CHANGED=0
LINK_CHANGED=0
HOME_CHANGED=0
grep -q "^scripts/packages.sh" <<< "$CHANGED_FILES" && PACKAGES_CHANGED=1
grep -qE "^(scripts/link.sh|home/|config/|claude/)" <<< "$CHANGED_FILES" && LINK_CHANGED=1
grep -qE "^home/" <<< "$CHANGED_FILES" && HOME_CHANGED=1

# ── Pull ──────────────────────────────────────────────────────────────────────
header "Pulling latest changes"
eval "$GIT pull --ff-only --quiet" && \
  echo "  ${C_GREEN}✓${C_RESET} Updated to ${C_DIM}$(git -C "$REPO_DIR" rev-parse --short HEAD)${C_RESET}"

# ── Re-run link.sh if dotfiles changed ───────────────────────────────────────
if [ "$LINK_CHANGED" = "1" ]; then
  header "Dotfiles/configs changed"
  if ask "Re-run link.sh to refresh symlinks?"; then
    bash "$REPO_DIR/scripts/link.sh"
    echo "  ${C_GREEN}✓${C_RESET} Symlinks refreshed"
  fi
fi

# ── Offer to re-run packages.sh if it changed ────────────────────────────────
if [ "$PACKAGES_CHANGED" = "1" ]; then
  header "packages.sh changed (new tools may be available)"
  if ask "Run packages.sh to install new tools?" "n"; then
    bash "$REPO_DIR/scripts/packages.sh"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_GREEN}==> Update complete.${C_RESET}"
if [ "$HOME_CHANGED" = "1" ]; then
  echo "  ${C_YELLOW}Tip:${C_RESET} reload your shell to pick up changes: ${C_CYAN}exec zsh${C_RESET}"
fi
echo ""
