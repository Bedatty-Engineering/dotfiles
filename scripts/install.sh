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

# Helper: within a category, optionally ask per-tool and set SKIP_<NAME>=1
pick_tools() {
  local category_name="$1"; shift
  local tools=("$@")
  if ask "    Pick tools individually? (otherwise install all in this category)"; then
    for tool in "${tools[@]}"; do
      local var="SKIP_$(echo "$tool" | tr '[:lower:]- /' '[:upper:]___' | tr -cd 'A-Z_')"
      if ! ask "      - $tool?"; then
        export "$var=1"
      fi
    done
  fi
}

if ask "Install packages?"; then
  if [ "$AUTO_YES" -eq 1 ]; then
    export INSTALL_SHELL=1 INSTALL_K8S=1 INSTALL_CLOUD=1 INSTALL_DEV=1 INSTALL_TERMINAL=1 INSTALL_EDITORS=1
    selected="all"
  else
    echo "    ${C_DIM}Choose which categories to install:${C_RESET}"
    selected=""
    INSTALL_SHELL=0;    INSTALL_K8S=0;      INSTALL_CLOUD=0
    INSTALL_DEV=0;      INSTALL_TERMINAL=0; INSTALL_EDITORS=0

    if ask "  • Shell tools?"; then
      INSTALL_SHELL=1; selected+="shell "
      pick_tools "Shell" oh-my-zsh zsh-autosuggestions zsh-syntax-highlighting fzf tmux-tpm "JetBrainsMono Nerd Font"
    fi
    if ask "  • Kubernetes?"; then
      INSTALL_K8S=1; selected+="k8s "
      pick_tools "Kubernetes" kubectl minikube kubectx/kubens helm k9s stern kustomize argocd
    fi
    if ask "  • Cloud?"; then
      INSTALL_CLOUD=1; selected+="cloud "
      pick_tools "Cloud" aws-cli ssm-plugin terraform openvpn
    fi
    if ask "  • Dev tools?"; then
      INSTALL_DEV=1; selected+="dev "
      pick_tools "Dev" docker python3 pipx bun gh claude-cli
    fi
    if ask "  • Terminal?"; then
      INSTALL_TERMINAL=1; selected+="terminal "
      pick_tools "Terminal" zoxide bat eza delta atuin direnv
    fi
    if ask "  • Editors?"; then
      INSTALL_EDITORS=1; selected+="editors "
      pick_tools "Editors" vscode cursor
    fi

    export INSTALL_SHELL INSTALL_K8S INSTALL_CLOUD INSTALL_DEV INSTALL_TERMINAL INSTALL_EDITORS
    [ -z "$selected" ] && selected="(none selected)"
  fi

  PACKAGES_SUMMARY_FILE="$HOME/.cache/dotfiles-packages-summary.txt"
  export PACKAGES_SUMMARY_FILE
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

# ── 5. Packages detail (re-print so it's at the end, not scrolled up) ────────
if [ -f "${PACKAGES_SUMMARY_FILE:-}" ]; then
  echo ""
  cat "$PACKAGES_SUMMARY_FILE"
fi

# ── 6. Next steps ─────────────────────────────────────────────────────────────
echo ""
echo "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
echo "${C_BOLD}${C_CYAN}║                     Next Steps (manual)                           ║${C_RESET}"
echo "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ Shell${C_RESET}"
echo "  Apply zsh as current shell:"
echo "      ${C_CYAN}exec zsh${C_RESET}   ${C_DIM}# or log out and back in${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ SSH keys${C_RESET}"
echo "  Copy your keys to ~/.ssh/ (github key, cluster keys, etc.):"
echo "      ${C_CYAN}cp /path/to/company_github_key ~/.ssh/${C_RESET}"
echo "      ${C_CYAN}chmod 600 ~/.ssh/company_github_key${C_RESET}"
echo "      ${C_CYAN}ssh-add ~/.ssh/company_github_key${C_RESET}"
echo "  Test: ${C_CYAN}ssh -T git@github.com${C_RESET}"
echo "  Reference: ${C_DIM}$DOTFILES_DIR/config/ssh/config.example${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ AWS (SSO)${C_RESET}"
echo "  The ~/.aws/config is already linked (profiles defined as placeholders)."
echo "  Edit with your real account IDs:"
echo "      ${C_CYAN}\$EDITOR $DOTFILES_DIR/config/aws/config${C_RESET}"
echo "  Login to SSO:"
echo "      ${C_CYAN}aws sso login --profile <profile>${C_RESET}"
echo "  Switch profile interactively:"
echo "      ${C_CYAN}awsp${C_RESET}   ${C_DIM}# fzf-based profile picker${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ Kubernetes${C_RESET}"
echo "  Copy cluster kubeconfigs (one per cluster) to ~/.kube/:"
echo "      ${C_CYAN}cp /path/to/alpha-k8s-config ~/.kube/${C_RESET}"
echo "  The .zshrc merges all *-config files automatically."
echo "  Switch cluster:   ${C_CYAN}kctx${C_RESET}   (alias of kubectx)"
echo "  Switch namespace: ${C_CYAN}kns${C_RESET}    (alias of kubens)"
echo "  UI for pods/logs: ${C_CYAN}k9s${C_RESET}"
echo "  Reference: ${C_DIM}$DOTFILES_DIR/config/kube/config.example${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ ArgoCD${C_RESET}"
echo "  Login to your ArgoCD server:"
echo "      ${C_CYAN}argocd login <argocd.example.com>${C_RESET}"
echo "  or via SSO:"
echo "      ${C_CYAN}argocd login <argocd.example.com> --sso${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ GitHub CLI${C_RESET}"
echo "      ${C_CYAN}gh auth login${C_RESET}   ${C_DIM}# follow interactive prompts${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ NPM (Lerian packages)${C_RESET}"
echo "      ${C_CYAN}echo '//npm.pkg.github.com/:_authToken=YOUR_TOKEN' >> ~/.npmrc${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ Docker${C_RESET}"
echo "  User was added to docker group — log out/in for it to take effect:"
echo "      ${C_CYAN}docker run hello-world${C_RESET}   ${C_DIM}# verify${C_RESET}"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ tmux plugins${C_RESET}"
echo "  Start tmux and press ${C_CYAN}prefix + I${C_RESET} (Ctrl+B, then Shift+I) to install plugins"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ atuin (shell history sync — optional)${C_RESET}"
echo "  Create account and sync history across machines:"
echo "      ${C_CYAN}atuin register -u <username> -e <email>${C_RESET}"
echo "      ${C_CYAN}atuin import auto${C_RESET}   ${C_DIM}# import existing history${C_RESET}"
echo "  Or just use locally without account: ${C_CYAN}Ctrl+R${C_RESET} to search history"

echo ""
echo "${C_BOLD}${C_YELLOW}▸ VS Code / Cursor${C_RESET}"
if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "  ${C_YELLOW}WSL detected.${C_RESET} The Linux builds were installed for completeness, but you should"
  echo "  install the Windows builds and use them via the ${C_CYAN}WSL${C_RESET} extension:"
  echo "      1. Install VS Code on Windows:  ${C_CYAN}https://code.visualstudio.com/download${C_RESET}"
  echo "      2. Install Cursor on Windows:   ${C_CYAN}https://cursor.com/download${C_RESET}"
  echo "      3. In VS Code Windows: install the ${C_CYAN}\"WSL\"${C_RESET} extension (ms-vscode-remote.remote-wsl)"
  echo "      4. From WSL, run ${C_CYAN}code .${C_RESET} or ${C_CYAN}cursor .${C_RESET} — aliases route to the Windows binaries"
else
  echo "  Sign in to sync settings and extensions:"
  echo "      ${C_CYAN}code${C_RESET}      ${C_DIM}# GitHub/Microsoft sign-in${C_RESET}"
  echo "      ${C_CYAN}cursor${C_RESET}    ${C_DIM}# Cursor account${C_RESET}"
fi

echo ""
echo "${C_BOLD}${C_YELLOW}▸ Terminal font (IMPORTANT)${C_RESET}"
echo "  Configure your terminal to use ${C_CYAN}JetBrainsMono Nerd Font${C_RESET}"
echo "  (otherwise eza icons and prompt symbols will appear broken)"
echo "  ${C_DIM}WSL → Windows Terminal: settings.json → profile → \"font\": { \"face\": \"JetBrainsMono Nerd Font\" }${C_RESET}"

echo ""
