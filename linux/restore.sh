#!/usr/bin/env bash
# Copy this repo's Linux dotfiles into your home dir, and install the tmux plugins.
#
#   git clone https://github.com/MariusDinita/dev-environment-vdi
#   bash dev-environment-vdi/linux/restore.sh
#
# What it does:
#   1. Copies .bashrc and .tmux.conf into ~ (backing up any existing files first).
#   2. Clones TPM if it's missing, then installs the plugins your .tmux.conf declares
#      (tpm, tmux-resurrect, tmux-continuum) via 'tmux-plugin install'.
#
# Needs git + internet for the plugin step; that step is best-effort and won't fail
# the dotfile copy. Requires tmux to be installed on the box for the plugins to be used.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. dotfiles ---
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

# --- 2. tmux plugins (via TPM) ---
TPM="$HOME/.tmux/plugins/tpm"
if command -v git >/dev/null 2>&1; then
  if [ ! -d "$TPM" ]; then
    echo "installing TPM -> $TPM"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$TPM" || echo "  (TPM clone failed)"
  fi
  if [ -x "$TPM/bin/tmux-plugin" ]; then
    echo "installing tmux plugins listed in .tmux.conf ..."
    "$TPM/bin/tmux-plugin" install \
      || echo "  (reported an issue; retry with: ~/.tmux/plugins/tpm/bin/tmux-plugin install, or open tmux and press prefix+I)"
  else
    echo "TPM not usable at $TPM; install plugins manually:"
    echo "  git clone https://github.com/tmux-plugins/tpm $TPM"
  fi
else
  echo "git not found; skipped tmux plugin install."
  echo "  install them later inside tmux with prefix+I (TPM), or install git and re-run this."
fi

echo
echo "done."
echo "  - open a new shell (or: source ~/.bashrc) to pick up .bashrc"
echo "  - if tmux itself isn't installed yet, install it first (e.g. 'sudo apt install tmux' on Ubuntu)"
