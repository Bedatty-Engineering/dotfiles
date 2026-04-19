#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

confirm() {
  local msg="$1"
  read -r -p "$msg [y/N] " answer
  [[ "${answer,,}" == "y" ]]
}

echo "==> Dotfiles Uninstaller"
echo "    This will remove symlinks, installed tools, and optionally the repo itself."
echo ""

# ── 1. Remove symlinks ────────────────────────────────────────────────────────
echo "==> Removing dotfile symlinks"
for src_file in "$DOTFILES_DIR/home"/.*; do
  [ -f "$src_file" ] || continue
  filename="$(basename "$src_file")"
  dest="$HOME/$filename"

  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src_file" ]; then
    rm "$dest"
    echo "  Removed symlink: $dest"

    # Restore backup if it exists
    if [ -f "${dest}.bak" ]; then
      mv "${dest}.bak" "$dest"
      echo "  Restored backup: ${dest}.bak -> $dest"
    fi
  fi
done

# ── 2. Oh-My-Zsh ─────────────────────────────────────────────────────────────
if [ -d "$HOME/.oh-my-zsh" ] && confirm "Remove Oh-My-Zsh (~/.oh-my-zsh)?"; then
  rm -rf "$HOME/.oh-my-zsh"
  echo "  Removed ~/.oh-my-zsh"
fi

# ── 3. zsh plugins ───────────────────────────────────────────────────────────
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  plugin_dir="$ZSH_CUSTOM/plugins/$plugin"
  if [ -d "$plugin_dir" ] && confirm "Remove zsh plugin: $plugin?"; then
    rm -rf "$plugin_dir"
    echo "  Removed $plugin_dir"
  fi
done

# ── 4. fzf ───────────────────────────────────────────────────────────────────
if [ -d "$HOME/.fzf" ] && confirm "Remove fzf (~/.fzf)?"; then
  "$HOME/.fzf/uninstall" 2>/dev/null || true
  rm -rf "$HOME/.fzf"
  echo "  Removed ~/.fzf"
fi

# ── 5. nvm + Node ────────────────────────────────────────────────────────────
if [ -d "$HOME/.nvm" ] && confirm "Remove nvm + Node.js (~/.nvm)?"; then
  rm -rf "$HOME/.nvm"
  echo "  Removed ~/.nvm"
fi

# ── 6. kubectl ───────────────────────────────────────────────────────────────
if command -v kubectl &>/dev/null && confirm "Remove kubectl (/usr/local/bin/kubectl)?"; then
  sudo rm -f /usr/local/bin/kubectl
  echo "  Removed kubectl"
fi

# ── 7. kubectx + kubens ──────────────────────────────────────────────────────
if [ -d /opt/kubectx ] && confirm "Remove kubectx/kubens (/opt/kubectx)?"; then
  sudo rm -f /usr/local/bin/kubectx /usr/local/bin/kubens
  sudo rm -rf /opt/kubectx
  echo "  Removed kubectx/kubens"
fi

# ── 8. AWS CLI v2 ────────────────────────────────────────────────────────────
if command -v aws &>/dev/null && confirm "Remove AWS CLI v2?"; then
  sudo /usr/local/aws-cli/v2/current/bin/aws_completer 2>/dev/null || true
  sudo rm -rf /usr/local/aws-cli
  sudo rm -f /usr/local/bin/aws /usr/local/bin/aws_completer
  echo "  Removed AWS CLI"
fi

# ── 9. ArgoCD CLI ────────────────────────────────────────────────────────────
if command -v argocd &>/dev/null && confirm "Remove ArgoCD CLI (/usr/local/bin/argocd)?"; then
  sudo rm -f /usr/local/bin/argocd
  echo "  Removed argocd"
fi

# ── 10. Restore default shell ────────────────────────────────────────────────
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" = "$(command -v zsh)" ] && confirm "Restore default shell to bash?"; then
  chsh -s "$(command -v bash)"
  echo "  Default shell restored to bash"
fi

# ── 11. Remove repo ──────────────────────────────────────────────────────────
REPO_DIR="$(cd "$DOTFILES_DIR/../.." && pwd)"
if confirm "Remove the dotfiles repo itself ($REPO_DIR)?"; then
  rm -rf "$REPO_DIR"
  echo "  Removed $REPO_DIR"
  echo ""
  echo "Done. Uninstall complete — restart your shell."
  exit 0
fi

echo ""
echo "Done. Uninstall complete — restart your shell."
