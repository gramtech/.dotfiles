# CLAUDE.md — dotfiles

Project-specific context for Claude Code.

## What this repo is

A portable development environment for macOS and Linux. `install.sh` is the single entry point — it installs packages, creates symlinks, and sets up the shell.

## Structure conventions

| Path | Purpose |
|---|---|
| `homebrew/Brewfile` | macOS packages (brew bundle) |
| `linux/install-packages.sh` | Linux packages (apt/dnf) with optional menu |
| `zsh/config/zsh/zshrc.common` | Shared zsh config (all platforms) |
| `zsh/config/zsh/zshrc.darwin` | macOS-only zsh config |
| `zsh/config/zsh/zshrc.linux` | Linux-only zsh config |
| `install.sh` | Bootstrap script — symlinks + package install |

## Key rules

- **Runtime versions go through asdf**, not Homebrew or apt directly. `brew "asdf"` on macOS; git clone on Linux.
- **OS-specific shell config belongs in the right file.** Anything that references `brew --prefix`, iTerm2, or 1Password goes in `zshrc.darwin`. Linux paths/aliases go in `zshrc.linux`. Shared logic goes in `zshrc.common`.
- **Linux supports both apt and dnf.** Any new Linux install function needs a `_apt` and `_dnf` variant (or a single path if the tool provides its own installer script like Helm).
- **SSH config is macOS only** — it references the 1Password socket. Don't symlink it on Linux.
- **Optional Linux tools** go in the `OPTIONAL_NAMES` / `OPTIONAL_DESCS` arrays in `linux/install-packages.sh` and get a case entry in `install_optional()`.
- **Syntax highlighting must be sourced last** in zsh config (both darwin and linux).

## Commit style

Short imperative subject line, body bullet points if needed. See recent commits for reference.
