#!/usr/bin/env bash
# Bootstrap script — can be run with:
# curl -fsSL https://raw.githubusercontent.com/bedatty/bedatty-engineernig/main/dotfiles/scripts/install.sh | bash
set -euo pipefail

REPO_URL="https://github.com/bedatty/bedatty-engineernig.git"
REPO_DIR="$HOME/personal/bedatty-engineernig"
DOTFILES_DIR="$REPO_DIR/dotfiles"

echo "==> Checking dependencies"
for dep in git curl zsh; do
  if ! command -v "$dep" &>/dev/null; then
    echo "  Missing: $dep — installing via apt"
    sudo apt-get install -y -qq "$dep"
  fi
done

echo "==> Cloning repository"
if [ -d "$REPO_DIR/.git" ]; then
  echo "  Repo already exists, pulling latest"
  git -C "$REPO_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

echo "==> Installing packages"
bash "$DOTFILES_DIR/scripts/packages.sh"

echo "==> Linking dotfiles"
bash "$DOTFILES_DIR/scripts/link.sh"

echo "==> Setting zsh as default shell"
if [ "$SHELL" != "$(command -v zsh)" ]; then
  chsh -s "$(command -v zsh)"
fi

echo ""
echo "Done! Restart your shell or run: exec zsh"
echo ""
echo "Manual steps required:"
echo "  1. Add SSH keys to ~/.ssh/ and set correct permissions (chmod 600)"
echo "  2. Configure AWS credentials: aws configure"
echo "  3. Set up ~/.npmrc with GitHub Package Registry token for Lerian packages:"
echo "     echo '//npm.pkg.github.com/:_authToken=YOUR_TOKEN' >> ~/.npmrc"
echo "  4. Load your SSH key into the agent: ssh-add ~/.ssh/lerian_github_key"
