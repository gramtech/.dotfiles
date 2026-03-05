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

# Back up a real file/dir (not a symlink) before it gets replaced.
# All backups for a given install run land in the same timestamped directory.
_BACKUP_DIR=""
backup_if_needed() {
  local target="$1"
  [[ -e "$target" || -L "$target" ]] || return 0  # nothing there — nothing to do
  [[ -L "$target" ]] && return 0                  # already a symlink — ln -sf handles it
  if [[ -z "$_BACKUP_DIR" ]]; then
    _BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$_BACKUP_DIR"
  fi
  mv "$target" "$_BACKUP_DIR/"
  warn "Backed up $(basename "$target") → $_BACKUP_DIR/"
}

create_symlinks() {
  info "Creating symlinks"

  # zsh entry points
  backup_if_needed "$HOME/.zshenv"
  ln -sf "$DOTFILES/zsh/.zshenv"   "$HOME/.zshenv"
  backup_if_needed "$HOME/.zprofile"
  ln -sf "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"
  backup_if_needed "$HOME/.zshrc"
  ln -sf "$DOTFILES/zsh/.zshrc"    "$HOME/.zshrc"
  ok "zsh"

  # ~/.config is a real dir (XDG standard, shared by many tools)
  mkdir -p "$HOME/.config"

  backup_if_needed "$HOME/.config/zsh"
  ln -sf "$DOTFILES/zsh/config/zsh" "$HOME/.config/zsh"
  ok "zsh config dir"

  # tmux
  backup_if_needed "$HOME/.tmux.conf"
  ln -sf "$DOTFILES/tmux/.tmux.conf" "$HOME/.tmux.conf"
  ok "tmux"

  # neovim
  backup_if_needed "$HOME/.config/nvim"
  ln -sf "$DOTFILES/nvim" "$HOME/.config/nvim"
  ok "neovim"

  # git
  backup_if_needed "$HOME/.gitconfig"
  ln -sf "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"
  ok "git (set identity in ~/.gitconfig.local)"

  # SSH — macOS only (config references 1Password socket)
  if [[ "$OS" == "Darwin" ]]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    backup_if_needed "$HOME/.ssh/config"
    ln -sf "$DOTFILES/ssh/config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    ok "SSH config (requires 1Password SSH agent)"
  fi

  [[ -n "$_BACKUP_DIR" ]] && info "Pre-existing files backed up to $_BACKUP_DIR"
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
