# .dotfiles

```
 ██████╗  ██████╗ ████████╗███████╗██╗██╗     ███████╗███████╗
 ██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝██║██║     ██╔════╝██╔════╝
 ██║  ██║██║   ██║   ██║   █████╗  ██║██║     █████╗  ███████╗
 ██║  ██║██║   ██║   ██║   ██╔══╝  ██║██║     ██╔══╝  ╚════██║
 ██████╔╝╚██████╔╝   ██║   ██║     ██║███████╗███████╗███████║
 ╚═════╝  ╚═════╝    ╚═╝   ╚═╝     ╚═╝╚══════╝╚══════╝╚══════╝
```

A portable, modular development environment for macOS and Linux. One install script bootstraps everything: packages, symlinks, shell config, and tooling — leaving a consistent setup on any machine.

**Stack at a glance:**

| Layer | Tool |
|---|---|
| Shell | Zsh (modular, OS-aware) |
| Terminal multiplexer | Tmux |
| Editor | Neovim (lazy.nvim) |
| Version manager | asdf |
| Package manager | Homebrew (macOS) / apt or dnf (Linux) |
| SSH agent | 1Password (macOS) |
| Infrastructure | Helm, Terraform |
| GitHub CLI | gh |
| Fuzzy finder | fzf + ripgrep |
| AI shell helpers | Claude (`ccmd`, `ccmd_in`) |

---

## Structure

```
.dotfiles/
├── bin/          # Utility scripts (install-terminfo)
├── homebrew/     # Brewfile for macOS packages
├── linux/        # Linux package installer script
├── nvim/         # Neovim configuration (lazy.nvim)
├── ssh/          # SSH client config (macOS / 1Password)
├── terminfo/     # Custom tmux-256color terminfo (italic support)
├── tmux/         # Tmux configuration
└── zsh/          # Zsh configuration (modular, OS-aware)
    ├── .zshenv
    ├── .zprofile
    ├── .zshrc
    └── config/zsh/
        ├── zshrc.common    # Shared config (history, fzf, aliases, Claude helpers)
        ├── zshrc.darwin    # macOS: Homebrew, iTerm2, 1Password SSH, asdf, zsh plugins
        ├── zshrc.linux     # Linux: PATH, fzf, asdf, zsh plugins, bat alias
        └── aliases.zsh
```

---

## Install

Clone the repo and run the install script:

**SSH:**
```sh
git clone git@github.com:gramtech/.dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

**HTTPS:**
```sh
git clone https://github.com/gramtech/.dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

The script will:
- Install all required packages (Homebrew + `brew bundle` on macOS; apt/dnf on Linux)
- Create all symlinks
- Install the custom terminfo
- Set zsh as the default shell if needed

**macOS packages** are defined in `homebrew/Brewfile` and installed via `brew bundle`.

**Linux packages** are installed via `linux/install-packages.sh`. After core tools are installed, it presents a menu for optional components:

```
Optional components
────────────────────────
  1. Docker CE + Compose + BuildX  (Docker's official repo)
  2. asdf version manager           (git clone, manages Node/Python/Go/etc.)
  3. GitHub CLI                     (GitHub's official repo)
  4. Helm                           (official get-helm-3 script)
  5. Terraform                      (HashiCorp's official repo)

  a  Install all
  i  Choose individually
  s  Skip all
```

### macOS — additional steps

1. Install [1Password](https://1password.com/) and enable the SSH agent under **Settings → Developer**
2. Install [iTerm2](https://iterm2.com/), then install shell integration (review the script before running):
   ```sh
   curl -fsSL https://iterm2.com/shell_integration/install_shell_integration.sh -o /tmp/iterm2_install.sh
   # Review /tmp/iterm2_install.sh, then:
   bash /tmp/iterm2_install.sh
   ```

### Linux — notes

- `eza` requires Ubuntu 23.10+ / Debian 13+. On older distros: `cargo install eza` or `snap install eza`
- Neovim from apt is often outdated. If the installed version is < 0.11, grab an [AppImage](https://github.com/neovim/neovim/releases) instead
- SSH config is **not** symlinked on Linux (it references the 1Password socket). Manage SSH keys directly or via your own agent setup

---

## What's Configured

### Zsh

- Modular: `zshrc.common` loaded on all platforms, then `zshrc.darwin` or `zshrc.linux`
- 20k line history, deduplicated, shared across sessions
- `t` — create or attach to a `main` tmux session
- `v` — alias for `nvim`
- fzf key bindings with ripgrep as the default search command
- fzf preview: history (`Ctrl+R`) with bat syntax highlighting, directory jump (`Alt+C`) with eza
- zsh-autosuggestions, zsh-history-substring-search, zsh-syntax-highlighting
- grc (Generic Colouriser) — colourizes output of `ip`, `ping`, `df`, `netstat`, `ps`, and more
- `ccmd` — ask Claude for next-command suggestions from the shell
- `ccmd_in` — pipe command output into Claude for diagnosis
- iTerm2 shell integration (macOS)

### Tmux

- Prefix: `Ctrl+A`
- Vi copy mode, windows start at index 1, 100k line scrollback
- Splits: `|` (horizontal), `-` (vertical)
- Pane navigation: `hjkl` with smart Neovim passthrough (`vim-tmux-navigator`)
- Preserves `SSH_AUTH_SOCK` across sessions

### Neovim

Plugin manager: [lazy.nvim](https://github.com/folke/lazy.nvim)

| Plugin | Purpose |
|---|---|
| Telescope | Fuzzy find files, grep, buffers |
| nvim-treesitter | Syntax parsing + textobjects (function/class select) |
| nvim-lspconfig + Mason | LSP: `lua_ls`, `bashls`, `yamlls`, `jsonls`, `terraformls`, `dockerls` |
| nvim-cmp + LuaSnip | Completion + snippets |
| Conform | Formatting: stylua, shfmt, jq, terraform_fmt |
| Gitsigns | Git diff in the gutter |
| which-key | Keybinding discovery |
| vim-tmux-navigator | Seamless Neovim/Tmux pane switching |

**Leader key**: `Space`

Key LSP bindings: `gd` (definition), `gr` (references), `K` (hover), `<leader>rn` (rename), `<leader>ca` (code action)

### Git

A shared `git/.gitconfig` is symlinked to `~/.gitconfig`. It sets sensible defaults (editor, pull rebase, useful aliases) and pulls in `~/.gitconfig.local` for machine-specific identity:

```ini
# ~/.gitconfig.local  (not tracked)
[user]
  name  = Your Name
  email = you@example.com
```

### asdf

Runtime versions are managed by [asdf](https://asdf-vm.com/). On macOS it is installed via Homebrew; on Linux via git clone into `~/.asdf`.

After install, add plugins and set global versions:

```sh
asdf plugin add nodejs
asdf plugin add python
asdf plugin add golang
asdf install nodejs latest
asdf global nodejs latest
```

Per-project versions are pinned with a `.tool-versions` file in the project root. A global `~/.tool-versions` can be symlinked from the dotfiles root to set machine-wide defaults.

### SSH

- Agent: 1Password SSH agent socket (macOS only)
- `ControlMaster` with 10-minute `ControlPersist` for fast reconnects
- `ServerAliveInterval 30`
