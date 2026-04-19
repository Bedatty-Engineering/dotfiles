#!/usr/bin/env bash
set -euo pipefail

is_installed() { command -v "$1" &>/dev/null; }

echo "==> Installing system packages"
sudo apt-get update -qq
sudo apt-get install -y -qq git curl wget zsh tmux unzip build-essential

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

echo "==> All packages installed."
