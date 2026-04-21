#!/usr/bin/env bash
# Bootstrap script — can be run with:
# curl -fsSL https://raw.githubusercontent.com/Bedatty-Engineering/dotfiles/main/scripts/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/Bedatty-Engineering/dotfiles.git"
REPO_DIR="$HOME/dotfiles"
DOTFILES_DIR="$REPO_DIR"

echo "==> Checking dependencies"
for dep in git curl zsh; do
  if ! command -v "$dep" &>/dev/null; then
    echo "  Missing: $dep — installing via apt"
    sudo apt-get install -y -qq "$dep"
  fi
done

echo "==> Cloning repository"
# Bypass the user's global gitconfig so any url.insteadOf rewrite
# does not force SSH before keys are set up
if [ -d "$REPO_DIR/.git" ]; then
  echo "  Repo already exists, pulling latest"
  GIT_CONFIG_GLOBAL=/dev/null git -C "$REPO_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$REPO_DIR")"
  GIT_CONFIG_GLOBAL=/dev/null git clone "$REPO_URL" "$REPO_DIR"
fi

ask() {
  local msg="$1"
  local answer
  if [ -t 0 ]; then
    read -r -p "$msg [Y/n] " answer
  else
    read -r -p "$msg [Y/n] " answer </dev/tty
  fi
  [[ "${answer,,}" != "n" ]]
}

echo ""
echo "==> What would you like to do?"

if ask "  Install packages (oh-my-zsh, fzf, kubectl, nvm, aws, argocd)?"; then
  bash "$DOTFILES_DIR/scripts/packages.sh"
fi

if ask "  Create dotfile symlinks in \$HOME?"; then
  bash "$DOTFILES_DIR/scripts/link.sh"
fi

if ask "  Set zsh as default shell?"; then
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    sudo chsh -s "$(command -v zsh)" "$USER" && \
      echo "  Default shell set to zsh. Log out and back in to apply." || \
      echo "  WARN: chsh failed. Run manually: sudo chsh -s \$(command -v zsh) \$USER"
  else
    echo "  zsh is already the default shell."
  fi
fi

if ask "  Install Ring (LerianStudio Claude skills and agents)?"; then
  echo "  Running Ring installer..."
  # Bypass global gitconfig so url.insteadOf rewrite doesn't force SSH
  GIT_CONFIG_GLOBAL=/dev/null \
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/lerianstudio/ring/main/install-ring.sh)"
fi

echo ""
echo "Done! Restart your shell or run: exec zsh"
echo ""
echo "Manual steps required:"
echo "  1. Add SSH keys to ~/.ssh/ and set correct permissions (chmod 600)"
echo "  2. Configure AWS credentials: aws configure"
echo "  3. Set up ~/.npmrc with GitHub Package Registry token for Lerian packages:"
echo "     echo '//npm.pkg.github.com/:_authToken=YOUR_TOKEN' >> ~/.npmrc"
echo "  4. Load your SSH key into the agent: ssh-add ~/.ssh/company_github_key"
