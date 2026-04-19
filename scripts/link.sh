#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${HOME}"

link_file() {
  local src="$1"
  local dest="$2"

  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "  Backup: $dest -> $dest.bak"
    mv "$dest" "$dest.bak"
  fi

  ln -sf "$src" "$dest"
  echo "  Linked: $dest -> $src"
}

echo "Linking dotfiles from $DOTFILES_DIR/home/ to $HOME_DIR/"

for src_file in "$DOTFILES_DIR/home"/.*; do
  [ -f "$src_file" ] || continue
  filename="$(basename "$src_file")"
  link_file "$src_file" "$HOME_DIR/$filename"
done

echo "Linking Claude config from $DOTFILES_DIR/claude/ to $HOME_DIR/.claude/"
mkdir -p "$HOME_DIR/.claude"

for src_file in "$DOTFILES_DIR/claude"/*; do
  [ -e "$src_file" ] || continue
  filename="$(basename "$src_file")"
  link_file "$src_file" "$HOME_DIR/.claude/$filename"
done

echo "Done."
