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
  echo -e "\n  ${BOLD}${question}${RESET} [y/N] \c"
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
    zsh tmux git curl wget \
    fzf ripgrep htop gnupg \
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
    zsh tmux git curl wget \
    fzf ripgrep htop gnupg2 \
    bat eza \
    zsh-autosuggestions zsh-syntax-highlighting \
    ca-certificates

  ok "Core packages installed"
}

# ── Neovim ─────────────────────────────────────────────────────────────────
# System packages are often outdated — install from official source instead

install_neovim_apt() {
  info "Installing Neovim (stable PPA)"
  sudo apt-get install -y software-properties-common
  sudo add-apt-repository -y ppa:neovim-ppa/stable
  sudo apt-get update -qq
  sudo apt-get install -y neovim
  ok "Neovim $(nvim --version | head -1) installed"
}

install_neovim_dnf() {
  info "Installing Neovim (dnf)"
  sudo dnf install -y neovim
  ok "Neovim $(nvim --version | head -1) installed"
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
  info "Adding Docker repository (apt)"

  # GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
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

  # Allow running docker without sudo
  sudo usermod -aG docker "$USER"

  ok "Docker $(docker --version) installed"
  warn "Log out and back in for docker group membership to take effect"
}

install_docker_dnf() {
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

  # Allow running docker without sudo
  sudo usermod -aG docker "$USER"

  ok "Docker $(docker --version) installed"
  warn "Log out and back in for docker group membership to take effect"
}

# ── Helm ───────────────────────────────────────────────────────────────────

install_helm() {
  info "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ok "Helm $(helm version --short) installed"
}

# ── Terraform ──────────────────────────────────────────────────────────────

install_terraform_apt() {
  info "Adding HashiCorp repository (apt)"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
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
  info "Adding HashiCorp repository (dnf)"
  sudo dnf install -y dnf-plugins-core
  sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
  sudo dnf install -y terraform
  ok "Terraform $(terraform version -json | grep '"terraform_version"' | cut -d '"' -f 4) installed"
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
    helm)    install_helm ;;
    terraform)
      case "$PKG_MANAGER" in
        apt) install_terraform_apt ;;
        dnf) install_terraform_dnf ;;
      esac
      ;;
  esac
}

OPTIONAL_NAMES=(docker asdf helm terraform)
OPTIONAL_DESCS=(
  "Docker CE + Compose + BuildX  (Docker's official repo)"
  "asdf version manager           (git clone, manages Node/Python/Go/etc.)"
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
