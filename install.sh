#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info() { echo -e "\n${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $*"; }
warn() { echo -e "  ${YELLOW}!${RESET} $*"; }

# ── macOS ─────────────────────────────────────────────────────────────────────

install_macos() {
  info "Checking Homebrew"
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
    [[ -x /usr/local/bin/brew ]]    && eval "$(/usr/local/bin/brew shellenv)"
  else
    ok "Homebrew already installed"
  fi

  info "Installing packages via Brewfile"
  brew bundle --file="$DOTFILES/homebrew/Brewfile"
  ok "Brewfile packages installed"

  # Install fzf shell key bindings (writes ~/.fzf.zsh, sourced by zshrc.darwin)
  local fzf_install="$(brew --prefix)/opt/fzf/install"
  if [[ -f "$fzf_install" ]]; then
    info "Installing fzf key bindings"
    "$fzf_install" --key-bindings --completion --no-update-rc
    ok "fzf key bindings installed"
  fi
}

# ── Linux ─────────────────────────────────────────────────────────────────────

install_linux() {
  "$DOTFILES/linux/install-packages.sh"
}

# ── Symlinks ──────────────────────────────────────────────────────────────────

create_symlinks() {
  info "Creating symlinks"

  # zsh entry points
  ln -sf "$DOTFILES/zsh/.zshenv"   "$HOME/.zshenv"
  ln -sf "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"
  ln -sf "$DOTFILES/zsh/.zshrc"    "$HOME/.zshrc"
  ok "zsh"

  # ~/.config is a real dir (XDG standard, shared by many tools)
  mkdir -p "$HOME/.config"

  # ~/.config/zsh is a symlink — if a real dir exists here, remove it first
  if [[ -d "$HOME/.config/zsh" && ! -L "$HOME/.config/zsh" ]]; then
    rm -rf "$HOME/.config/zsh"
  fi
  ln -sf "$DOTFILES/zsh/config/zsh" "$HOME/.config/zsh"
  ok "zsh config dir"

  # tmux
  ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
  ok "tmux"

  # neovim
  ln -sf "$DOTFILES/nvim" "$HOME/.config/nvim"
  ok "neovim"

  # SSH — macOS only (config references 1Password socket)
  if [[ "$OS" == "Darwin" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ln -sf "$DOTFILES/ssh/config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    ok "SSH config (requires 1Password SSH agent)"
  fi
}

# ── Terminfo ──────────────────────────────────────────────────────────────────

install_terminfo() {
  info "Installing terminfo"
  "$DOTFILES/bin/install-terminfo"
  ok "tmux-256color terminfo installed"
}

# ── Default shell ─────────────────────────────────────────────────────────────

set_default_shell() {
  local zsh_path; zsh_path="$(command -v zsh)"
  if [[ "$SHELL" == "$zsh_path" ]]; then
    ok "Default shell is already zsh"
    return
  fi
  info "Setting default shell to zsh"
  if ! grep -qF "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$zsh_path"
  ok "Default shell set to $zsh_path (takes effect on next login)"
}

# ── Main ──────────────────────────────────────────────────────────────────────

echo -e "\n${BOLD}dotfiles install${RESET}"
echo "──────────────────"

case "$OS" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *)      warn "Unsupported OS: $OS"; exit 1 ;;
esac

create_symlinks
install_terminfo
set_default_shell

echo -e "\n${GREEN}${BOLD}Done.${RESET}"

if [[ "$OS" == "Darwin" ]]; then
  echo ""
  echo "Remaining macOS steps:"
  echo "  • Open 1Password and enable the SSH agent under Settings → Developer"
  echo "  • Install iTerm2 shell integration: curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash"
fi
