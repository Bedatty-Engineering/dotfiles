#!/usr/bin/env bash
set -euo pipefail

is_installed() { command -v "$1" &>/dev/null; }

echo "==> Installing system packages"
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget zsh tmux unzip build-essential jq

# Oh-My-Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh-My-Zsh"
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# zsh-autosuggestions
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  echo "==> Installing zsh-autosuggestions"
  git clone --depth=1 https://github.com/ziahamza/webui-aria2 \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 2>/dev/null || \
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  echo "==> Installing zsh-syntax-highlighting"
  git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# fzf
if [ ! -d "$HOME/.fzf" ]; then
  echo "==> Installing fzf"
  git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
fi

# Bun (runtime + package manager, replaces nvm/node/npm)
if ! is_installed bun; then
  echo "==> Installing Bun"
  curl -fsSL https://bun.sh/install | bash
  export PATH="$HOME/.bun/bin:$PATH"
fi

# kubectl
if ! is_installed kubectl; then
  echo "==> Installing kubectl"
  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi

# minikube
if ! is_installed minikube; then
  echo "==> Installing minikube"
  curl -fsSLo /tmp/minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
  sudo install -m 0755 /tmp/minikube /usr/local/bin/minikube
  rm /tmp/minikube
fi

# kubectx + kubens
if ! is_installed kubectx; then
  echo "==> Installing kubectx/kubens"
  sudo git clone --depth=1 https://github.com/ahmetb/kubectx /opt/kubectx
  sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx
  sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens
fi

# AWS CLI v2
if ! is_installed aws; then
  echo "==> Installing AWS CLI v2"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp/awscliv2
  sudo /tmp/awscliv2/aws/install
  rm -rf /tmp/awscliv2 /tmp/awscliv2.zip
fi

# ArgoCD CLI
if ! is_installed argocd; then
  echo "==> Installing ArgoCD CLI"
  ARGOCD_VERSION="$(curl -fsSL https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)"
  curl -fsSLo /tmp/argocd "https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64"
  sudo install -m 0755 /tmp/argocd /usr/local/bin/argocd
fi

# Terraform
if ! is_installed terraform; then
  echo "==> Installing Terraform"
  wget -qO /tmp/terraform.zip "https://releases.hashicorp.com/terraform/$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')/terraform_$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')_linux_amd64.zip"
  unzip -q /tmp/terraform.zip -d /tmp/terraform
  sudo install -m 0755 /tmp/terraform/terraform /usr/local/bin/terraform
  rm -rf /tmp/terraform /tmp/terraform.zip
fi

# GitHub CLI
if ! is_installed gh; then
  echo "==> Installing GitHub CLI"
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
  sudo apt-get update -qq && sudo apt-get install -y -qq gh
fi

# OpenVPN
if ! is_installed openvpn; then
  echo "==> Installing OpenVPN"
  sudo apt-get install -y -qq openvpn
fi

# Claude Code CLI
if ! is_installed claude; then
  echo "==> Installing Claude Code CLI"
  npm install -g @anthropic-ai/claude-code 2>/dev/null || \
  bun install -g @anthropic-ai/claude-code
fi

# Nerd Fonts (JetBrainsMono — needed for custom prompt icons)
FONTS_DIR="${HOME}/.local/share/fonts"
if ! fc-list | grep -qi "JetBrainsMono"; then
  echo "==> Installing JetBrainsMono Nerd Font"
  mkdir -p "$FONTS_DIR"
  curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
    | tar -xJ -C "$FONTS_DIR"
  fc-cache -fv "$FONTS_DIR" &>/dev/null
fi

# direnv (per-project environment variables)
if ! is_installed direnv; then
  echo "==> Installing direnv"
  curl -fsSL https://direnv.net/install.sh | bash
fi

# Docker
if ! is_installed docker; then
  echo "==> Installing Docker"
  curl -fsSL https://get.docker.com | bash
  sudo usermod -aG docker "$USER"
  echo "  Note: log out and back in for docker group to take effect"
fi

# Python3 + pip + pipx
if ! is_installed python3; then
  echo "==> Installing Python3"
  sudo apt-get install -y -qq python3 python3-pip python3-venv pipx
fi
if ! is_installed pipx; then
  sudo apt-get install -y -qq pipx
  pipx ensurepath
fi

# Helm
if ! is_installed helm; then
  echo "==> Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# k9s
if ! is_installed k9s; then
  echo "==> Installing k9s"
  K9S_VERSION="$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d'"' -f4)"
  curl -fsSLo /tmp/k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
  tar -xzf /tmp/k9s.tar.gz -C /tmp k9s
  sudo install -m 0755 /tmp/k9s /usr/local/bin/k9s
  rm /tmp/k9s.tar.gz /tmp/k9s
fi

# stern (multi-pod log tailing)
if ! is_installed stern; then
  echo "==> Installing stern"
  STERN_VERSION="$(curl -fsSL https://api.github.com/repos/stern/stern/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d v)"
  curl -fsSLo /tmp/stern.tar.gz "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz"
  tar -xzf /tmp/stern.tar.gz -C /tmp stern
  sudo install -m 0755 /tmp/stern /usr/local/bin/stern
  rm /tmp/stern.tar.gz /tmp/stern
fi

# kustomize
if ! is_installed kustomize; then
  echo "==> Installing kustomize"
  curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/kustomize
fi

# AWS Session Manager Plugin
if ! is_installed session-manager-plugin; then
  echo "==> Installing AWS Session Manager Plugin"
  curl -fsSLo /tmp/ssm-plugin.deb "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
  sudo dpkg -i /tmp/ssm-plugin.deb
  rm /tmp/ssm-plugin.deb
fi

# zoxide (smarter cd)
if ! is_installed zoxide; then
  echo "==> Installing zoxide"
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
fi

# bat (better cat)
if ! is_installed bat; then
  echo "==> Installing bat"
  sudo apt-get install -y -qq bat || \
    { BAT_VERSION="$(curl -fsSL https://api.github.com/repos/sharkdp/bat/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d v)"
      curl -fsSLo /tmp/bat.deb "https://github.com/sharkdp/bat/releases/download/v${BAT_VERSION}/bat_${BAT_VERSION}_amd64.deb"
      sudo dpkg -i /tmp/bat.deb && rm /tmp/bat.deb; }
fi

# eza (better ls)
if ! is_installed eza; then
  echo "==> Installing eza"
  sudo apt-get install -y -qq gpg
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -qq && sudo apt-get install -y -qq eza
fi

# delta (better git diff)
if ! is_installed delta; then
  echo "==> Installing delta"
  DELTA_VERSION="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | grep tag_name | cut -d'"' -f4)"
  curl -fsSLo /tmp/delta.deb "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
  sudo dpkg -i /tmp/delta.deb && rm /tmp/delta.deb
fi

# atuin (shell history sync)
if ! is_installed atuin; then
  echo "==> Installing atuin"
  curl -fsSL https://setup.atuin.sh | bash
fi

# tmux plugin manager (tpm)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing tmux plugin manager"
  git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# VS Code
if ! is_installed code; then
  echo "==> Installing VS Code"
  curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list
  sudo apt-get update -qq && sudo apt-get install -y -qq code
fi

# Cursor
if ! is_installed cursor; then
  echo "==> Installing Cursor"
  (
    set +e
    CURSOR_URL="$(curl -fsSL "https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable" 2>/dev/null \
      | jq -r '.downloadUrl // .url // empty')"
    if [ -z "$CURSOR_URL" ]; then
      echo "  WARN: could not resolve Cursor download URL, skipping"
    else
      curl -fsSLo /tmp/cursor.AppImage "$CURSOR_URL" && \
        chmod +x /tmp/cursor.AppImage && \
        sudo mv /tmp/cursor.AppImage /usr/local/bin/cursor && \
        echo "  Cursor installed" || \
        echo "  WARN: Cursor install failed, skipping"
    fi
  )
fi

echo "==> All packages installed."
