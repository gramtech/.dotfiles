# .dotfiles

macOS-focused development environment: SSH via 1Password, Zsh, Tmux, and Neovim.

## Structure

```
.dotfiles/
├── bin/          # Utility scripts
├── nvim/         # Neovim configuration (lazy.nvim)
├── ssh/          # SSH client config
├── terminfo/     # Custom tmux-256color terminfo (italic support)
├── tmux/         # Tmux configuration
└── zsh/          # Zsh configuration (modular, OS-aware)
```

## Setup

### 1. Terminfo

Install the custom terminfo for proper italic support in tmux:

```sh
./bin/install-terminfo
```

### 2. SSH

Symlink or copy `ssh/config` to `~/.ssh/config`. Requires [1Password](https://1password.com/) with the SSH agent enabled.

### 3. Zsh

Symlink the zsh config files:

```sh
ln -sf ~/.dotfiles/zsh/.zshenv ~/.zshenv
ln -sf ~/.dotfiles/zsh/.zprofile ~/.zprofile
ln -sf ~/.dotfiles/zsh/.zshrc ~/.zshrc
```

### 4. Tmux

Symlink the tmux config:

```sh
ln -sf ~/.dotfiles/tmux/.tmux.conf ~/.tmux.conf
```

### 5. Neovim

Symlink the nvim config:

```sh
ln -sf ~/.dotfiles/nvim ~/.config/nvim
```

## What's Configured

### Zsh

- Modular: `zshrc.common` + OS-specific overlays (`zshrc.darwin`, `zshrc.linux`)
- 20k line history, deduplicated, shared across sessions
- `t` function: create or attach to a `main` tmux session
- `v` alias for `nvim`
- fzf integration (macOS, via Homebrew)
- iTerm2 shell integration (macOS)

### Tmux

- Prefix: `Ctrl+A`
- Vi copy mode, windows start at index 1, 100k line scrollback
- Splits: `|` (horizontal), `-` (vertical)
- Pane navigation: `hjkl` (integrates with Neovim splits via smart passthrough)
- Preserves `SSH_AUTH_SOCK` across sessions for 1Password SSH agent

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

- Agent: 1Password SSH agent socket
- `ControlMaster` with 10-minute `ControlPersist` for fast reconnects
- `ServerAliveInterval 30`
