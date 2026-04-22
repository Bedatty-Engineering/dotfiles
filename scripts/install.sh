#!/usr/bin/env bash
# Bootstrap script — can be run with:
# curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/Bedatty-Engineering/dotfiles.git"
REPO_DIR="$HOME/dotfiles"
DOTFILES_DIR="$REPO_DIR"

AUTO_YES=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) AUTO_YES=1 ;;
    -h|--help) echo "Usage: install.sh [-y|--yes]"; exit 0 ;;
  esac
done

# ── Colors ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

# ── Summary tracking ──────────────────────────────────────────────────────────
declare -A STEPS
declare -a STEP_ORDER

record() {
  local name="$1" status="$2" detail="${3:-}"
  STEPS[$name]="${status}|${detail}"
  STEP_ORDER+=("$name")
}

header() {
  echo ""
  echo "${C_BOLD}${C_CYAN}==> $1${C_RESET}"
}

ask() {
  local msg="$1" answer
  if [ "$AUTO_YES" -eq 1 ]; then
    echo "  $msg [Y/n] ${C_DIM}(auto-yes)${C_RESET}"
    return 0
  fi
  if [ -t 0 ]; then
    read -r -p "  $msg [Y/n] " answer
  else
    read -r -p "  $msg [Y/n] " answer </dev/tty
  fi
  [[ "${answer,,}" != "n" ]]
}

step_done() {
  echo "  ${C_GREEN}✓${C_RESET} $1 ${C_DIM}complete${C_RESET}"
}
step_skip() {
  echo "  ${C_DIM}○ $1 skipped${C_RESET}"
}
step_fail() {
  echo "  ${C_RED}✗${C_RESET} $1 ${C_DIM}failed${C_RESET}"
}

# ── 1. Dependencies ───────────────────────────────────────────────────────────
header "Checking dependencies"
missing=()
for dep in git curl zsh; do
  if ! command -v "$dep" &>/dev/null; then
    missing+=("$dep")
    echo "  ${C_YELLOW}Missing:${C_RESET} $dep — installing via apt"
    sudo apt-get install -y -qq "$dep"
  fi
done
if [ ${#missing[@]} -eq 0 ]; then
  record "Dependencies" "ok" "git, curl, zsh already present"
else
  record "Dependencies" "ok" "installed: ${missing[*]}"
fi

# ── 2. Clone repo ─────────────────────────────────────────────────────────────
header "Cloning repository"
if [ -d "$REPO_DIR/.git" ]; then
  GIT_CONFIG_GLOBAL=/dev/null git -C "$REPO_DIR" pull --ff-only
  record "Repository" "ok" "updated ($REPO_DIR)"
else
  mkdir -p "$(dirname "$REPO_DIR")"
  GIT_CONFIG_GLOBAL=/dev/null git clone "$REPO_URL" "$REPO_DIR"
  record "Repository" "ok" "cloned into $REPO_DIR"
fi

# ── 3. Interactive steps ──────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_CYAN}==> What would you like to do?${C_RESET}"

if ask "Install packages?"; then
  if [ "$AUTO_YES" -eq 1 ]; then
    export INSTALL_SHELL=1 INSTALL_K8S=1 INSTALL_CLOUD=1 INSTALL_DEV=1 INSTALL_TERMINAL=1 INSTALL_EDITORS=1
    selected="all"
  else
    echo "    ${C_DIM}Choose which categories to install:${C_RESET}"
    selected=""
    INSTALL_SHELL=0;    ask "  • Shell tools (oh-my-zsh, fzf, tmux plugins, Nerd Fonts)?"             && INSTALL_SHELL=1    && selected+="shell "
    INSTALL_K8S=0;      ask "  • Kubernetes (kubectl, kubectx, helm, k9s, stern, kustomize, argocd)?" && INSTALL_K8S=1      && selected+="k8s "
    INSTALL_CLOUD=0;    ask "  • Cloud (aws cli, ssm, terraform, openvpn)?"                           && INSTALL_CLOUD=1    && selected+="cloud "
    INSTALL_DEV=0;      ask "  • Dev tools (docker, python, bun, gh, claude cli)?"                    && INSTALL_DEV=1      && selected+="dev "
    INSTALL_TERMINAL=0; ask "  • Terminal (zoxide, bat, eza, delta, atuin, direnv)?"                  && INSTALL_TERMINAL=1 && selected+="terminal "
    INSTALL_EDITORS=0;  ask "  • Editors (vscode, cursor)?"                                           && INSTALL_EDITORS=1  && selected+="editors "
    export INSTALL_SHELL INSTALL_K8S INSTALL_CLOUD INSTALL_DEV INSTALL_TERMINAL INSTALL_EDITORS
    [ -z "$selected" ] && selected="(none selected)"
  fi

  if bash "$DOTFILES_DIR/scripts/packages.sh"; then
    record "Packages" "ok" "categories: $selected"
    step_done "Packages"
  else
    record "Packages" "fail" "some installations failed"
    step_fail "Packages"
  fi
else
  record "Packages" "skip" "user chose not to install"
  step_skip "Packages"
fi

if ask "Create dotfile symlinks in \$HOME?"; then
  if bash "$DOTFILES_DIR/scripts/link.sh"; then
    record "Symlinks" "ok" "dotfiles linked to \$HOME"
    step_done "Symlinks"
  else
    record "Symlinks" "fail" "link.sh returned error"
    step_fail "Symlinks"
  fi
else
  record "Symlinks" "skip" "user chose not to link"
  step_skip "Symlinks"
fi

if ask "Set zsh as default shell?"; then
  if [ "$SHELL" = "$(command -v zsh)" ]; then
    record "Default shell" "ok" "already zsh"
    step_done "Default shell (already zsh)"
  elif sudo chsh -s "$(command -v zsh)" "$USER" 2>/dev/null; then
    record "Default shell" "ok" "set to zsh (logout to apply)"
    step_done "Default shell set to zsh"
  else
    record "Default shell" "fail" "run manually: sudo chsh -s \$(which zsh) \$USER"
    step_fail "Default shell"
  fi
else
  record "Default shell" "skip" "user chose to keep current shell"
  step_skip "Default shell"
fi

if ask "Install Ring (LerianStudio Claude skills and agents)?"; then
  if GIT_CONFIG_GLOBAL=/dev/null \
     bash -c "$(curl -fsSL https://raw.githubusercontent.com/lerianstudio/ring/main/install-ring.sh)"; then
    record "Ring" "ok" "ring-default plugin installed"
    step_done "Ring"
  else
    record "Ring" "fail" "installer exited with error"
    step_fail "Ring"
  fi
else
  record "Ring" "skip" "user chose not to install"
  step_skip "Ring"
fi

# ── 4. Summary ────────────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
echo "${C_BOLD}${C_CYAN}║                       Installation Summary                       ║${C_RESET}"
echo "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"
echo ""
printf "  %-16s %-8s %s\n" "STEP" "STATUS" "DETAIL"
printf "  %-16s %-8s %s\n" "────" "──────" "──────"
for name in "${STEP_ORDER[@]}"; do
  IFS='|' read -r status detail <<< "${STEPS[$name]}"
  case "$status" in
    ok)   icon="${C_GREEN}✓ ok${C_RESET}   " ;;
    skip) icon="${C_DIM}○ skip${C_RESET} " ;;
    fail) icon="${C_RED}✗ fail${C_RESET} " ;;
    *)    icon="$status  " ;;
  esac
  printf "  %-16s %b %s\n" "$name" "$icon" "${C_DIM}${detail}${C_RESET}"
done

# ── 5. Next steps ─────────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_YELLOW}Next steps (manual):${C_RESET}"
echo "  1. Restart shell or run: ${C_CYAN}exec zsh${C_RESET}"
echo "  2. Copy SSH keys to ~/.ssh/ and ${C_CYAN}chmod 600${C_RESET} them"
echo "  3. ${C_CYAN}aws sso login --profile <profile>${C_RESET}"
echo "  4. Copy kubeconfigs to ~/.kube/*-config"
echo "  5. ${C_CYAN}ssh-add ~/.ssh/company_github_key${C_RESET}"
echo "  6. ${C_CYAN}atuin register${C_RESET} (optional — enable history sync)"
echo ""
