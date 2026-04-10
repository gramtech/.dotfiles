#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info()   { echo -e "\n${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }
ok()     { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()   { echo -e "  ${YELLOW}!${RESET} $*"; }
prompt() { printf "\n  ${BOLD}%s${RESET} [y/N] " "$1"; read -r _a; [[ "$_a" =~ ^[Yy]$ ]]; }

# ── macOS ─────────────────────────────────────────────────────────────────────

install_macos() {
  info "Checking Homebrew"
  if ! command -v brew >/dev/null 2>&1; then
    info "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"; fi
    if [[ -x /usr/local/bin/brew ]];    then eval "$(/usr/local/bin/brew shellenv)"; fi
  else
    ok "Homebrew already installed"
  fi

  info "Installing packages via Brewfile"
  brew bundle --file="$DOTFILES/homebrew/Brewfile"
  ok "Brewfile packages installed"

  # Install fzf shell key bindings (writes ~/.fzf.zsh, sourced by zshrc.darwin)
  local fzf_install="$(brew --prefix)/opt/fzf/install"
  if [[ -f "$fzf_install" ]] && [[ ! -f "$HOME/.fzf.zsh" ]]; then
    info "Installing fzf key bindings"
    "$fzf_install" --key-bindings --completion --no-update-rc --no-bash --no-fish
    ok "fzf key bindings installed"
  elif [[ -f "$HOME/.fzf.zsh" ]]; then
    ok "fzf key bindings already installed"
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
  if [[ ! -e "$target" && ! -L "$target" ]]; then return 0; fi  # nothing there — nothing to do
  if [[ -L "$target" ]]; then return 0; fi                      # already a symlink — ln -sf handles it
  if [[ -z "$_BACKUP_DIR" ]]; then
    _BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p -m 700 "$_BACKUP_DIR"
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

  if [[ -n "$_BACKUP_DIR" ]]; then info "Pre-existing files backed up to $_BACKUP_DIR"; fi
}

# ── asdf tool versions ────────────────────────────────────────────────────────

setup_asdf_tools() {
  [[ -f "$DOTFILES/.tool-versions" ]] || return 0
  command -v asdf >/dev/null 2>&1 || { warn "asdf not found, skipping tool setup"; return 0; }

  info "Setting up asdf tool versions"
  while IFS=' ' read -r name version; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    asdf install "$name" "$version" 2>/dev/null || true
    asdf set -u "$name" "$version"
    ok "$name $version set as global"
  done < "$DOTFILES/.tool-versions"
}

# ── Git identity ──────────────────────────────────────────────────────────────

setup_git_identity() {
  if [[ -f "$HOME/.gitconfig.local" ]]; then
    ok "Git identity already set (~/.gitconfig.local exists)"
    return
  fi

  echo ""
  echo -e "  ${BOLD}Set up git identity?${RESET}"
  echo -e "  ~/.gitconfig.local stores your name and email for git commits."
  echo -e "  This file is ${BOLD}not${RESET} tracked in the repo — it stays on this machine only."
  printf "  Create it now? [y/N] "
  read -r answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    warn "Skipped — create ~/.gitconfig.local manually before committing:"
    warn "  [user]"
    warn "    name  = Your Name"
    warn "    email = you@example.com"
    return
  fi

  echo ""
  printf "  Your full name (appears in git commit history): "
  read -r git_name
  printf "  Your email (appears in git commit history):     "
  read -r git_email

  printf '[user]\n\tname  = %s\n\temail = %s\n' "$git_name" "$git_email" \
    > "$HOME/.gitconfig.local" \
    || { warn "Failed to write ~/.gitconfig.local"; return 1; }

  ok "Git identity saved to ~/.gitconfig.local"
}

# ── Neovim AI ─────────────────────────────────────────────────────────────────

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    ok "Ollama already installed"
    return
  fi
  info "Installing Ollama"
  if [[ "$OS" == "Darwin" ]]; then
    brew install ollama
  else
    curl -fsSL https://ollama.com/install.sh | sh
  fi
  ok "Ollama installed"
}

_nvim_ai_default_set() {
  local value="$1"   # "copilot" or remove
  local file="$HOME/.zshrc.local"
  if [[ "$value" == "remove" ]]; then
    [[ -f "$file" ]] || return 0
    if [[ "$OS" == "Darwin" ]]; then
      sed -i '' '/^export NVIM_AI_DEFAULT=/d' "$file"
    else
      sed -i '/^export NVIM_AI_DEFAULT=/d' "$file"
    fi
  else
    if [[ -f "$file" ]] && grep -q "NVIM_AI_DEFAULT" "$file"; then
      if [[ "$OS" == "Darwin" ]]; then
        sed -i '' "s/^export NVIM_AI_DEFAULT=.*/export NVIM_AI_DEFAULT=${value}/" "$file"
      else
        sed -i "s/^export NVIM_AI_DEFAULT=.*/export NVIM_AI_DEFAULT=${value}/" "$file"
      fi
    else
      echo "export NVIM_AI_DEFAULT=${value}" >> "$file"
    fi
  fi
}

setup_nvim_ai() {
  echo ""
  echo -e "  ${BOLD}Neovim AI plugins${RESET}"
  echo -e "  The config supports Copilot, Ollama (local), and Claude Code."
  echo -e "  You can enable any combination — they don't conflict."
  prompt "Set up AI plugins for Neovim?" || { ok "Skipped Neovim AI setup"; return; }

  local _copilot=false _ollama=false _claude=false

  # ── Copilot ────────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}GitHub Copilot${RESET}"
  echo "  Inline ghost-text completions as you type, with cycling alternatives."
  echo "  Requires an active GitHub Copilot licence (personal or work)."
  if prompt "Enable Copilot?"; then
    _copilot=true
    warn "After opening Neovim, run:  :Copilot auth"
    warn "This opens GitHub in your browser to link your licence."
    ok "Copilot enabled — complete auth inside Neovim"
  fi

  # ── Ollama ─────────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}Ollama — local AI models${RESET}"
  echo "  Runs models on this machine. Provides both ghost-text completions"
  echo "  and a chat interface. No internet or API key required."
  if prompt "Install Ollama?"; then
    _ollama=true
    install_ollama

    echo ""
    echo -e "  ${BOLD}Ghost text model${RESET} — needs a FIM-capable model for inline completions."
    echo "  Recommended: qwen2.5-coder:7b  (~4 GB)"
    prompt "Pull qwen2.5-coder:7b now?" && {
      ollama pull qwen2.5-coder:7b
      ok "qwen2.5-coder:7b pulled  (enable ghost text in Neovim with <leader>ag)"
    } || warn "Pull later:  ollama pull qwen2.5-coder:7b"

    echo ""
    echo -e "  ${BOLD}Chat model${RESET} — for the AI chat interface in Neovim."
    echo "  Recommended: llama3.2  (~2 GB).  Change in nvim/init.lua to use another."
    prompt "Pull llama3.2 now?" && {
      ollama pull llama3.2
      ok "llama3.2 pulled  (open AI chat in Neovim with <leader>ac)"
    } || warn "Pull later:  ollama pull llama3.2"
  fi

  # ── Claude ─────────────────────────────────────────────────────────────────
  echo ""
  echo -e "  ${BOLD}Claude Code${RESET}"
  echo "  Sidebar chat powered by the Claude Code CLI — no API key needed,"
  echo "  uses your existing Claude Code login."
  if prompt "Enable Claude integration?"; then
    _claude=true
    if command -v claude >/dev/null 2>&1; then
      ok "claude CLI found — Claude sidebar ready  (<leader>at in Neovim)"
    else
      warn "claude CLI not found — install it first, then the integration works automatically."
      warn "  https://claude.ai/code  or:  npm install -g @anthropic-ai/claude-code"
    fi
  fi

  # ── Derive startup default ─────────────────────────────────────────────────
  # Copilot-only → set Copilot as the auto-trigger default.
  # Ollama present (with or without Copilot) → Ollama is default; Copilot
  # available via <leader>am toggle.
  if [[ "$_copilot" == true && "$_ollama" == false ]]; then
    _nvim_ai_default_set "copilot"
    ok "Startup default: Copilot  (toggle to Ollama later with <leader>am)"
  elif [[ "$_ollama" == true ]]; then
    _nvim_ai_default_set "remove"
    ok "Startup default: Ollama/local  (toggle to Copilot with <leader>am)"
  else
    _nvim_ai_default_set "remove"
  fi

  echo ""
  ok "Neovim AI setup complete — open Neovim and run:  :Lazy sync"
}

# ── iTerm2 profile ────────────────────────────────────────────────────────────

setup_iterm2_profile() {
  local src="$DOTFILES/iterm2/dotfiles.json"
  local dest_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
  local dest="$dest_dir/dotfiles.json"

  if [[ -L "$dest" ]]; then
    ok "iTerm2 profile already linked"
    return
  fi

  echo ""
  echo -e "  ${BOLD}Install iTerm2 profile?${RESET}"
  echo -e "  This adds a new profile called ${BOLD}Dotfiles${RESET} to iTerm2."
  echo -e "  It sets the font to JetBrainsMono Nerd Font."
  echo -e "  ${BOLD}It will not modify or delete any existing profiles.${RESET}"
  echo -e "  After install, select it in iTerm2: Preferences → Profiles → Dotfiles → Other Actions → Set as Default"
  printf "  Install it? [y/N] "
  read -r answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    ok "Skipped iTerm2 profile"
    return
  fi

  mkdir -p "$dest_dir"
  ln -sf "$src" "$dest"
  ok "iTerm2 profile linked — restart iTerm2, then set Dotfiles as default in Preferences → Profiles"
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
  # Read the actual login shell from passwd — $SHELL can be stale in the current session
  local login_shell
  if command -v getent >/dev/null 2>&1; then
    login_shell="$(getent passwd "$USER" | cut -d: -f7)"
  else
    login_shell="$(grep "^${USER}:" /etc/passwd | cut -d: -f7)"
  fi
  if [[ "$login_shell" == "$zsh_path" ]]; then
    ok "Default shell is already zsh"
    return
  fi
  info "Setting default shell to zsh"
  if ! grep -qF "$zsh_path" /etc/shells; then
    echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
  fi
  # usermod is non-interactive and doesn't require the user's password;
  # chsh (macOS / fallback) prompts for it which breaks scripted installs
  if command -v usermod >/dev/null 2>&1; then
    sudo usermod -s "$zsh_path" "$USER"
  else
    chsh -s "$zsh_path"
  fi
  ok "Default shell set to $zsh_path — log out and back in for it to take effect"
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
setup_asdf_tools
setup_git_identity
setup_nvim_ai
install_terminfo
set_default_shell
if [[ "$OS" == "Darwin" ]]; then setup_iterm2_profile; fi

echo -e "\n${GREEN}${BOLD}Done.${RESET}"

if [[ "$OS" == "Darwin" ]]; then
  echo ""
  echo "Remaining macOS steps:"
  echo "  • Open 1Password and enable the SSH agent under Settings → Developer"
  echo "  • Install iTerm2 shell integration:"
  echo "      curl -fsSL https://iterm2.com/shell_integration/install_shell_integration.sh -o /tmp/iterm2_shell_integration.sh"
  echo "      # review the script, then: bash /tmp/iterm2_shell_integration.sh"
fi
