#!/usr/bin/env bash
# Copy this repo's Linux dotfiles into your home directory.
#
#   git clone https://github.com/MariusDinita/dev-environment-vdi
#   bash dev-environment-vdi/linux/restore.sh
#
# Safe to re-run: any existing file is backed up with a timestamp before it's replaced.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for f in .bashrc .tmux.conf; do
  src="$DIR/$f"
  [ -f "$src" ] || { echo "skip: $src not found"; continue; }
  if [ -f "$HOME/$f" ]; then
    bak="$HOME/$f.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$HOME/$f" "$bak"
    echo "backed up existing $HOME/$f -> $bak"
  fi
  cp "$src" "$HOME/$f"
  echo "restored $HOME/$f"
done
echo "done. Open a new shell (or: source ~/.bashrc) to pick up changes."
