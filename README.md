# .dotfiles

macOS and Linux development environment: Zsh, Tmux, Neovim, SSH via 1Password, Helm, Terraform.

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
        ├── zshrc.darwin    # macOS: Homebrew, iTerm2, 1Password SSH, zsh plugins
        ├── zshrc.linux     # Linux: PATH, fzf, zsh plugins, bat alias
        └── aliases.zsh
```

## Install

Clone the repo and run the install script:

```sh
git clone git@github.com:youruser/dotfiles.git ~/.dotfiles
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
  2. Node.js                        (via NVM)
  3. Helm                           (official get-helm-3 script)
  4. Terraform                      (HashiCorp's official repo)

  a  Install all
  i  Choose individually
  s  Skip all
```

### macOS — additional steps

1. Install [1Password](https://1password.com/) and enable the SSH agent under **Settings → Developer**
2. Install [iTerm2](https://iterm2.com/), then install shell integration:
   ```sh
   curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash
   ```

### Linux — notes

- `eza` requires Ubuntu 23.10+ / Debian 13+. On older distros: `cargo install eza` or `snap install eza`
- Neovim from apt is often outdated. If the installed version is < 0.9, grab an [AppImage](https://github.com/neovim/neovim/releases) instead
- SSH config is **not** symlinked on Linux (it references the 1Password socket). Manage SSH keys directly or via your own agent setup

## What's Configured

### Zsh

- Modular: `zshrc.common` loaded on all platforms, then `zshrc.darwin` or `zshrc.linux`
- 20k line history, deduplicated, shared across sessions
- `t` — create or attach to a `main` tmux session
- `v` — alias for `nvim`
- fzf key bindings with ripgrep as the default search command
- fzf preview: history (`Ctrl+R`) with bat syntax highlighting, directory jump (`Alt+C`) with eza
- zsh-autosuggestions, zsh-history-substring-search, zsh-syntax-highlighting
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

### SSH

- Agent: 1Password SSH agent socket (macOS only)
- `ControlMaster` with 10-minute `ControlPersist` for fast reconnects
- `ServerAliveInterval 30`
