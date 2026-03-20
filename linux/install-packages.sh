#!/usr/bin/env bash
set -euo pipefail

#  ---------------------------------------------------------------------------
#
#  Linux Package Installer
#  Installs core tools via system package manager, then prompts for optional
#  components that require third-party repositories (Docker, Node via NVM).
#
#  Usage: ~/.dotfiles/linux/install-packages.sh
#
#  ---------------------------------------------------------------------------

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info() { echo -e "\n${BLUE}==>${RESET} ${BOLD}$*${RESET}"; }
ok()   { echo -e "  ${GREEN}✓${RESET} $*"; }
warn() { echo -e "  ${YELLOW}!${RESET} $*"; }

prompt() {
  local question="$1"
  printf "\n  %b [y/N] " "${BOLD}${question}${RESET}"
  read -r answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# ── Detect package manager ─────────────────────────────────────────────────

if command -v apt-get >/dev/null 2>&1; then
  PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER="dnf"
else
  echo "Unsupported package manager. Only apt and dnf are supported."
  exit 1
fi

ok "Detected package manager: $PKG_MANAGER"

# ── Core packages ──────────────────────────────────────────────────────────

install_core_apt() {
  info "Installing core packages (apt)"
  sudo apt-get update -qq
  sudo apt-get install -y \
    zsh tmux git curl wget unzip \
    fzf ripgrep htop gnupg \
    grc \
    zsh-autosuggestions zsh-syntax-highlighting \
    ca-certificates apt-transport-https

  # bat: named 'batcat' on older Ubuntu/Debian
  if apt-cache show bat >/dev/null 2>&1; then
    sudo apt-get install -y bat
  else
    sudo apt-get install -y batcat
  fi

  # eza: Ubuntu 23.10+ / Debian 13+
  if apt-cache show eza >/dev/null 2>&1; then
    sudo apt-get install -y eza
  else
    warn "eza not in apt — install via: cargo install eza  OR  snap install eza"
  fi

  ok "Core packages installed"
}

install_core_dnf() {
  info "Installing core packages (dnf)"
  sudo dnf install -y \
    zsh tmux git curl wget unzip \
    fzf ripgrep htop gnupg2 \
    bat eza grc \
    zsh-autosuggestions zsh-syntax-highlighting \
    ca-certificates

  ok "Core packages installed"
}

# ── Neovim ─────────────────────────────────────────────────────────────────
# System packages are often outdated — install from official source instead

install_neovim_apt() {
  info "Installing Neovim (latest stable AppImage)"
  local dest="$HOME/.local/bin"
  mkdir -p "$dest"
  local url
  url=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest \
    | grep '"browser_download_url"' \
    | grep 'nvim-linux-x86_64\.appimage"' \
    | cut -d '"' -f 4)
  if [[ -z "$url" ]]; then
    warn "Could not determine latest Neovim AppImage URL; skipping"
    return 1
  fi
  curl -fsSL "$url" -o "$dest/nvim"
  chmod +x "$dest/nvim"
  ok "Neovim $("$dest/nvim" --version | head -1) installed to $dest/nvim"
}

install_neovim_dnf() {
  info "Installing Neovim (dnf)"
  sudo dnf install -y neovim
  ok "Neovim $(nvim --version | head -1) installed"
}

# ── Fonts ──────────────────────────────────────────────────────────────────

install_fonts() {
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if [[ -d "$font_dir" ]]; then
    ok "JetBrains Mono Nerd Font already installed"
    return
  fi
  info "Installing JetBrains Mono Nerd Font"
  local url
  url=$(curl -fsSL https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest \
    | grep '"browser_download_url"' \
    | grep 'JetBrainsMono\.tar\.xz"' \
    | cut -d '"' -f 4)
  if [[ -z "$url" ]]; then
    warn "Could not determine JetBrains Mono Nerd Font download URL; skipping"
    return 1
  fi
  local tmp
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/JetBrainsMono.tar.xz"
  mkdir -p "$font_dir"
  tar -xf "$tmp/JetBrainsMono.tar.xz" -C "$font_dir"
  rm -rf "$tmp"
  fc-cache -f "$font_dir"
  ok "JetBrains Mono Nerd Font installed"
  warn "Set it in your terminal emulator: JetBrainsMono Nerd Font, Regular"
}

# ── zsh plugins (user-local fallback) ─────────────────────────────────────
# Clone plugins to ~/.zsh/ for distros that don't package them.
# zshrc.linux sources system paths first and falls back to these.

_clone_zsh_plugin() {
  local name="$1" url="$2"
  local dest="$HOME/.zsh/$name"
  if [[ ! -d "$dest" ]]; then
    info "Cloning $name"
    git clone --depth=1 "$url" "$dest"
    ok "Cloned to $dest"
  else
    ok "$name already present"
  fi
}

install_zsh_plugins() {
  mkdir -p "$HOME/.zsh"
  _clone_zsh_plugin zsh-autosuggestions \
    https://github.com/zsh-users/zsh-autosuggestions.git
  _clone_zsh_plugin zsh-history-substring-search \
    https://github.com/zsh-users/zsh-history-substring-search.git
  _clone_zsh_plugin zsh-syntax-highlighting \
    https://github.com/zsh-users/zsh-syntax-highlighting.git
}

# ── Docker ─────────────────────────────────────────────────────────────────

install_docker_apt() {
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed ($(docker --version))"
  else
    info "Adding Docker repository (apt)"

    # GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -qq
    sudo apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

    ok "Docker $(docker --version) installed"
  fi

  # Allow running docker without sudo
  if ! groups "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "Log out and back in for docker group membership to take effect"
  fi
}

install_docker_dnf() {
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed ($(docker --version))"
  else
    info "Adding Docker repository (dnf)"
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

    sudo systemctl enable --now docker

    ok "Docker $(docker --version) installed"
  fi

  # Allow running docker without sudo
  if ! groups "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "Log out and back in for docker group membership to take effect"
  fi
}

# ── Helm ───────────────────────────────────────────────────────────────────

install_helm() {
  if command -v helm >/dev/null 2>&1; then
    ok "Helm already installed ($(helm version --short))"
    return
  fi
  info "Installing Helm"
  local tmp
  tmp="$(mktemp)"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o "$tmp"
  chmod +x "$tmp"
  "$tmp"
  rm -f "$tmp"
  ok "Helm $(helm version --short) installed"
}

# ── Terraform ──────────────────────────────────────────────────────────────

install_terraform_apt() {
  if command -v terraform >/dev/null 2>&1; then
    ok "Terraform already installed ($(terraform version -json | grep '"terraform_version"' | cut -d '"' -f 4))"
    return
  fi
  info "Adding HashiCorp repository (apt)"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --yes --dearmor -o /etc/apt/keyrings/hashicorp.gpg
  sudo chmod a+r /etc/apt/keyrings/hashicorp.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp.gpg] \
    https://apt.releases.hashicorp.com \
    $(. /etc/os-release && echo "$VERSION_CODENAME") main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y terraform
  ok "Terraform $(terraform version -json | grep '"terraform_version"' | cut -d '"' -f 4) installed"
}

install_terraform_dnf() {
  if command -v terraform >/dev/null 2>&1; then
    ok "Terraform already installed ($(terraform version -json | grep '"terraform_version"' | cut -d '"' -f 4))"
    return
  fi
  info "Adding HashiCorp repository (dnf)"
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  sudo dnf install -y terraform
  ok "Terraform $(terraform version -json | grep '"terraform_version"' | cut -d '"' -f 4) installed"
}

# ── GitHub CLI ─────────────────────────────────────────────────────────────

install_gh_apt() {
  if command -v gh >/dev/null 2>&1; then
    ok "gh already installed ($(gh --version | head -1))"
    return
  fi
  info "Adding GitHub CLI repository (apt)"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo gpg --yes --dearmor -o /etc/apt/keyrings/githubcli.gpg
  sudo chmod a+r /etc/apt/keyrings/githubcli.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli.gpg] \
    https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update -qq
  sudo apt-get install -y gh
  ok "gh $(gh --version | head -1) installed"
}

install_gh_dnf() {
  if command -v gh >/dev/null 2>&1; then
    ok "gh already installed ($(gh --version | head -1))"
    return
  fi
  info "Installing GitHub CLI (dnf)"
  sudo dnf install -y gh
  ok "gh $(gh --version | head -1) installed"
}

# ── asdf version manager ───────────────────────────────────────────────────

install_asdf() {
  if [[ -d "$HOME/.asdf" ]]; then
    ok "asdf already installed at ~/.asdf"
    return
  fi
  info "Installing asdf"
  local version
  version=$(curl -s https://api.github.com/repos/asdf-vm/asdf/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)
  trap 'rm -rf "$HOME/.asdf"; echo "asdf clone failed, cleaned up partial directory"' ERR
  git clone --depth=1 --branch "$version" \
    https://github.com/asdf-vm/asdf.git "$HOME/.asdf"
  trap - ERR
  ok "asdf ${version} installed"
  warn "Run 'source ~/.zshrc' to activate asdf, then add plugins with: asdf plugin add <name>"
}

# ── Main ───────────────────────────────────────────────────────────────────

echo -e "\n${BOLD}Linux package installer${RESET}"
echo "────────────────────────"

# Core
case "$PKG_MANAGER" in
  apt)
    install_core_apt
    install_neovim_apt
    ;;
  dnf)
    install_core_dnf
    install_neovim_dnf
    ;;
esac

install_zsh_plugins
install_fonts

# ── Optional components ─────────────────────────────────────────────────────

install_optional() {
  local name="$1"
  case "$name" in
    docker)
      case "$PKG_MANAGER" in
        apt) install_docker_apt ;;
        dnf) install_docker_dnf ;;
      esac
      ;;
    asdf)    install_asdf ;;
    gh)
      case "$PKG_MANAGER" in
        apt) install_gh_apt ;;
        dnf) install_gh_dnf ;;
      esac
      ;;
    helm)    install_helm ;;
    terraform)
      case "$PKG_MANAGER" in
        apt) install_terraform_apt ;;
        dnf) install_terraform_dnf ;;
      esac
      ;;
  esac
}

OPTIONAL_NAMES=(docker asdf gh helm terraform)
OPTIONAL_DESCS=(
  "Docker CE + Compose + BuildX  (Docker's official repo)"
  "asdf version manager           (git clone, manages Node/Python/Go/etc.)"
  "GitHub CLI                     (GitHub's official repo)"
  "Helm                           (official get-helm-3 script)"
  "Terraform                      (HashiCorp's official repo)"
)

echo -e "\n${BOLD}Optional components${RESET}"
echo "────────────────────────"
for i in "${!OPTIONAL_NAMES[@]}"; do
  printf "  %d. %s\n" "$((i+1))" "${OPTIONAL_DESCS[$i]}"
done
echo ""
echo -e "  ${BOLD}a${RESET}  Install all"
echo -e "  ${BOLD}i${RESET}  Choose individually"
echo -e "  ${BOLD}s${RESET}  Skip all"
echo ""
printf "  Choice [a/i/s]: "
read -r mode

case "$mode" in
  a|A)
    for name in "${OPTIONAL_NAMES[@]}"; do
      install_optional "$name"
    done
    ;;
  i|I)
    for i in "${!OPTIONAL_NAMES[@]}"; do
      name="${OPTIONAL_NAMES[$i]}"
      desc="${OPTIONAL_DESCS[$i]}"
      printf "\n  Install %s? [y/N] " "$desc"
      read -r answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        install_optional "$name"
      else
        ok "Skipping ${name}"
      fi
    done
    ;;
  *)
    ok "Skipping all optional components"
    ;;
esac

echo -e "\n${GREEN}${BOLD}Done.${RESET}\n"
