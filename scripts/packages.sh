#!/usr/bin/env bash
# Install packages. Each category is gated by an env var (defaults to 1 = install).
set -euo pipefail

: "${INSTALL_SHELL:=1}"
: "${INSTALL_K8S:=1}"
: "${INSTALL_CLOUD:=1}"
: "${INSTALL_DEV:=1}"
: "${INSTALL_TERMINAL:=1}"
: "${INSTALL_EDITORS:=1}"

if [ -t 1 ]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_DIM=""; C_BOLD=""; C_RESET=""
fi

# Tracking: category → list of "name:status" entries
declare -A CATEGORIES
declare -a CATEGORY_ORDER=("Shell" "Kubernetes" "Cloud" "Dev" "Terminal" "Editors")

track() {
  local category="$1" tool="$2" status="$3"
  CATEGORIES["$category"]+="${tool}:${status}|"
}

# Per-tool skip vars (SKIP_<UPPERCASE_NAME>=1 to skip that tool specifically)
skip_key() {
  echo "SKIP_$(echo "$1" | tr '[:lower:]- /' '[:upper:]___' | tr -cd 'A-Z_')"
}

install_tool() {
  local category="$1" name="$2" check="$3" install_cmd="$4"
  local var
  var="$(skip_key "$name")"
  if [ "${!var:-0}" = "1" ]; then
    track "$category" "$name" "skipped"
    return 0
  fi
  if eval "$check" &>/dev/null; then
    track "$category" "$name" "present"
    return 0
  fi
  echo "==> Installing $name"
  if eval "$install_cmd"; then
    track "$category" "$name" "installed"
  else
    track "$category" "$name" "failed"
  fi
}

is_installed() { command -v "$1" &>/dev/null; }

echo "${C_BOLD}${C_CYAN}==> Installing base system packages${C_RESET}"
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget zsh tmux unzip build-essential jq

# ════════════════════════════════════════════════════════════════════════════
# SHELL
# ════════════════════════════════════════════════════════════════════════════
if [ "$INSTALL_SHELL" = "1" ]; then
  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  install_tool "Shell" "oh-my-zsh" '[ -d "$HOME/.oh-my-zsh" ]' \
    'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

  install_tool "Shell" "zsh-autosuggestions" '[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]' \
    'git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"'

  install_tool "Shell" "zsh-syntax-highlighting" '[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]' \
    'git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"'

  install_tool "Shell" "fzf" '[ -d "$HOME/.fzf" ]' \
    'git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf" && "$HOME/.fzf/install" --all --no-bash --no-fish'

  install_tool "Shell" "tmux-tpm" '[ -d "$HOME/.tmux/plugins/tpm" ]' \
    'git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"'

  install_tool "Shell" "JetBrainsMono Nerd Font" 'fc-list | grep -qi JetBrainsMono' \
    'mkdir -p "$HOME/.local/share/fonts" && curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" | tar -xJ -C "$HOME/.local/share/fonts" && fc-cache -f &>/dev/null'
fi

# ════════════════════════════════════════════════════════════════════════════
# KUBERNETES
# ════════════════════════════════════════════════════════════════════════════
if [ "$INSTALL_K8S" = "1" ]; then
  install_tool "Kubernetes" "kubectl" "is_installed kubectl" \
    'V="$(curl -fsSL https://dl.k8s.io/release/stable.txt)" && curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${V}/bin/linux/amd64/kubectl" && sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl'

  install_tool "Kubernetes" "minikube" "is_installed minikube" \
    'curl -fsSLo /tmp/minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64" && sudo install -m 0755 /tmp/minikube /usr/local/bin/minikube && rm /tmp/minikube'

  install_tool "Kubernetes" "kubectx/kubens" "is_installed kubectx" \
    'sudo git clone --depth=1 https://github.com/ahmetb/kubectx /opt/kubectx && sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx && sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens'

  install_tool "Kubernetes" "helm" "is_installed helm" \
    'curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'

  install_tool "Kubernetes" "k9s" "is_installed k9s" \
    'V="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d"\"" -f4)" && curl -fsSLo /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${V}/k9s_Linux_amd64.tar.gz" && tar -xzf /tmp/k9s.tar.gz -C /tmp k9s && sudo install -m 0755 /tmp/k9s /usr/local/bin/k9s && rm /tmp/k9s.tar.gz /tmp/k9s'

  install_tool "Kubernetes" "stern" "is_installed stern" \
    'V="$(curl -fsSL https://api.github.com/repos/stern/stern/releases/latest | grep tag_name | cut -d"\"" -f4 | tr -d v)" && curl -fsSLo /tmp/stern.tar.gz "https://github.com/stern/stern/releases/download/v${V}/stern_${V}_linux_amd64.tar.gz" && tar -xzf /tmp/stern.tar.gz -C /tmp stern && sudo install -m 0755 /tmp/stern /usr/local/bin/stern && rm /tmp/stern.tar.gz /tmp/stern'

  install_tool "Kubernetes" "kustomize" "is_installed kustomize" \
    'curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash && sudo mv kustomize /usr/local/bin/kustomize'

  install_tool "Kubernetes" "argocd" "is_installed argocd" \
    'V="$(curl -fsSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)" && curl -fsSLo /tmp/argocd "https://github.com/argoproj/argo-cd/releases/download/v${V}/argocd-linux-amd64" && sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd'
fi

# ════════════════════════════════════════════════════════════════════════════
# CLOUD
# ════════════════════════════════════════════════════════════════════════════
if [ "$INSTALL_CLOUD" = "1" ]; then
  install_tool "Cloud" "aws-cli" "is_installed aws" \
    'curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && unzip -q /tmp/awscliv2.zip -d /tmp/awscliv2 && sudo /tmp/awscliv2/aws/install && rm -rf /tmp/awscliv2 /tmp/awscliv2.zip'

  install_tool "Cloud" "ssm-plugin" "is_installed session-manager-plugin" \
    'curl -fsSLo /tmp/ssm.deb "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" && sudo dpkg -i /tmp/ssm.deb && rm /tmp/ssm.deb'

  install_tool "Cloud" "terraform" "is_installed terraform" \
    'V="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)" && wget -qO /tmp/tf.zip "https://releases.hashicorp.com/terraform/${V}/terraform_${V}_linux_amd64.zip" && unzip -q /tmp/tf.zip -d /tmp/tf && sudo install -m 0755 /tmp/tf/terraform /usr/local/bin/terraform && rm -rf /tmp/tf /tmp/tf.zip'

  install_tool "Cloud" "openvpn" "is_installed openvpn" \
    'sudo apt-get install -y -qq openvpn'
fi

# ════════════════════════════════════════════════════════════════════════════
# DEV
# ════════════════════════════════════════════════════════════════════════════
if [ "$INSTALL_DEV" = "1" ]; then
  install_tool "Dev" "docker" "is_installed docker" \
    'curl -fsSL https://get.docker.com | bash && sudo usermod -aG docker "$USER"'

  install_tool "Dev" "python3" "is_installed python3" \
    'sudo apt-get install -y -qq python3 python3-pip python3-venv'

  install_tool "Dev" "pipx" "is_installed pipx" \
    'sudo apt-get install -y -qq pipx && pipx ensurepath'

  install_tool "Dev" "bun" "is_installed bun" \
    'curl -fsSL https://bun.sh/install | bash'

  install_tool "Dev" "gh" "is_installed gh" \
    'curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list && sudo apt-get update -qq && sudo apt-get install -y -qq gh'

  install_tool "Dev" "claude-cli" "is_installed claude" \
    'npm install -g @anthropic-ai/claude-code 2>/dev/null || bun install -g @anthropic-ai/claude-code'
fi

# ════════════════════════════════════════════════════════════════════════════
# TERMINAL
# ════════════════════════════════════════════════════════════════════════════
if [ "$INSTALL_TERMINAL" = "1" ]; then
  install_tool "Terminal" "zoxide" "is_installed zoxide" \
    'curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash'

  install_tool "Terminal" "bat" "is_installed bat" \
    'sudo apt-get install -y -qq bat || { V="$(curl -fsSL https://api.github.com/repos/sharkdp/bat/releases/latest | grep tag_name | cut -d\"\\\"\" -f4 | tr -d v)"; curl -fsSLo /tmp/bat.deb "https://github.com/sharkdp/bat/releases/download/v${V}/bat_${V}_amd64.deb"; sudo dpkg -i /tmp/bat.deb && rm /tmp/bat.deb; }'

  install_tool "Terminal" "eza" "is_installed eza" \
    'sudo mkdir -p /etc/apt/keyrings && wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg && echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list && sudo apt-get update -qq && sudo apt-get install -y -qq eza'

  install_tool "Terminal" "delta" "is_installed delta" \
    'V="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | grep tag_name | cut -d"\"" -f4)" && curl -fsSLo /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${V}/git-delta_${V}_amd64.deb" && sudo dpkg -i /tmp/delta.deb && rm /tmp/delta.deb'

  install_tool "Terminal" "atuin" "is_installed atuin" \
    'curl -fsSL https://setup.atuin.sh | bash'

  install_tool "Terminal" "direnv" "is_installed direnv" \
    'curl -fsSL https://direnv.net/install.sh | bash'
fi

# ════════════════════════════════════════════════════════════════════════════
# EDITORS
# ════════════════════════════════════════════════════════════════════════════
if [ "$INSTALL_EDITORS" = "1" ]; then
  install_tool "Editors" "vscode" "is_installed code" \
    'curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list && sudo apt-get update -qq && sudo apt-get install -y -qq code'

  install_tool "Editors" "cursor" "is_installed cursor" \
    'URL="$(curl -fsSL "https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable" 2>/dev/null | jq -r ".downloadUrl // .url // empty")" && [ -n "$URL" ] && curl -fsSLo /tmp/cursor.AppImage "$URL" && chmod +x /tmp/cursor.AppImage && sudo mv /tmp/cursor.AppImage /usr/local/bin/cursor'
fi

# ════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════════════════════════════════════
SUMMARY_FILE="${PACKAGES_SUMMARY_FILE:-$HOME/.cache/dotfiles-packages-summary.txt}"
mkdir -p "$(dirname "$SUMMARY_FILE")"

build_summary() {
  echo "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo "${C_BOLD}${C_CYAN}║                      Packages Installed                          ║${C_RESET}"
  echo "${C_BOLD}${C_CYAN}╚══════════════════════════════════════════════════════════════════╝${C_RESET}"
  for cat in "${CATEGORY_ORDER[@]}"; do
    entries="${CATEGORIES[$cat]:-}"
    [ -z "$entries" ] && continue
    echo ""
    echo "  ${C_BOLD}${C_YELLOW}▸ $cat${C_RESET}"
    IFS='|' read -ra items <<< "$entries"
    for item in "${items[@]}"; do
      [ -z "$item" ] && continue
      name="${item%:*}"; status="${item##*:}"
      case "$status" in
        installed) icon="${C_GREEN}+ installed${C_RESET}" ;;
        present)   icon="${C_DIM}= present  ${C_RESET}" ;;
        skipped)   icon="${C_DIM}○ skipped  ${C_RESET}" ;;
        failed)    icon="${C_RED}✗ failed   ${C_RESET}" ;;
      esac
      printf "      %b  %s\n" "$icon" "$name"
    done
  done
}

echo ""
build_summary | tee "$SUMMARY_FILE"
echo ""
echo "${C_BOLD}${C_GREEN}==> All selected packages processed.${C_RESET}"
