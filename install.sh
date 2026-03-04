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

  info "Installing packages"
  brew install \
    neovim tmux fzf \
    ripgrep bat eza \
    zsh-autosuggestions \
    zsh-history-substring-search \
    zsh-syntax-highlighting

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
  if command -v apt-get >/dev/null 2>&1; then
    install_apt
    clone_zsh_plugins  # zsh-history-substring-search not in apt
  elif command -v dnf >/dev/null 2>&1; then
    install_dnf
    clone_zsh_plugins  # zsh-history-substring-search not in dnf
  elif command -v pacman >/dev/null 2>&1; then
    install_pacman     # all plugins available in arch repos
  else
    warn "Unknown package manager. Install manually: zsh tmux neovim fzf ripgrep bat eza"
    warn "Then re-run this script."
    exit 1
  fi
}

install_apt() {
  info "Installing packages (apt)"
  sudo apt-get update -qq

  local pkgs=(zsh tmux fzf ripgrep zsh-autosuggestions zsh-syntax-highlighting)

  # bat: 'bat' on Ubuntu 22.04+, 'batcat' on older — zshrc.linux aliases batcat→bat
  if apt-cache show bat >/dev/null 2>&1; then
    pkgs+=(bat)
  else
    pkgs+=(batcat)
  fi

  # neovim
  if apt-cache show neovim >/dev/null 2>&1; then
    pkgs+=(neovim)
  else
    warn "neovim not found in apt — install manually: https://github.com/neovim/neovim/releases"
  fi

  # eza: Ubuntu 23.10+ / Debian 13+; older distros need cargo or snap
  if apt-cache show eza >/dev/null 2>&1; then
    pkgs+=(eza)
  else
    warn "eza not in apt — install via: cargo install eza  OR  snap install eza"
  fi

  sudo apt-get install -y "${pkgs[@]}"

  # Warn if installed neovim is old
  if command -v nvim >/dev/null 2>&1; then
    local ver; ver="$(nvim --version | head -1)"
    warn "$ver — if < 0.9, grab a newer AppImage from https://github.com/neovim/neovim/releases"
  fi
}

install_dnf() {
  info "Installing packages (dnf)"
  sudo dnf install -y \
    zsh tmux neovim fzf ripgrep bat eza \
    zsh-autosuggestions zsh-syntax-highlighting
}

install_pacman() {
  info "Installing packages (pacman)"
  sudo pacman -Sy --noconfirm \
    zsh tmux neovim fzf ripgrep bat eza \
    zsh-autosuggestions zsh-syntax-highlighting \
    zsh-history-substring-search
}

clone_zsh_plugins() {
  # zsh-history-substring-search isn't in apt/dnf repos — clone to ~/.zsh/
  # zshrc.linux already checks this path as a fallback
  local dest="$HOME/.zsh/zsh-history-substring-search"
  if [[ ! -d "$dest" ]]; then
    info "Cloning zsh-history-substring-search"
    git clone --depth=1 \
      https://github.com/zsh-users/zsh-history-substring-search.git \
      "$dest"
    ok "Cloned to $dest"
  else
    ok "zsh-history-substring-search already present"
  fi
}

# ── Symlinks ──────────────────────────────────────────────────────────────────

create_symlinks() {
  info "Creating symlinks"

  # zsh entry points
  ln -sf "$DOTFILES/zsh/.zshenv"   "$HOME/.zshenv"
  ln -sf "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"
  ln -sf "$DOTFILES/zsh/.zshrc"    "$HOME/.zshrc"
  ok "zsh"

  # zsh config dir (~/.config/zsh → dotfiles/zsh/config/zsh)
  mkdir -p "$HOME/.config"
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
  echo "  • Install 1Password and enable the SSH agent"
  echo "  • Install iTerm2, then: curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash"
fi
