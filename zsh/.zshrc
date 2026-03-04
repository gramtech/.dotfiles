# ~/.zshrc — dispatcher for modular zsh config

# Stop if non-interactive shell
[[ -o interactive ]] || return

# Load shared config
if [[ -r "$HOME/.config/zsh/zshrc.common" ]]; then
  source "$HOME/.config/zsh/zshrc.common"
fi

# Load OS-specific overlay
case "$(uname -s)" in
  Darwin)
    [[ -r "$HOME/.config/zsh/zshrc.darwin" ]] && source "$HOME/.config/zsh/zshrc.darwin"
    ;;
  Linux)
    [[ -r "$HOME/.config/zsh/zshrc.linux" ]] && source "$HOME/.config/zsh/zshrc.linux"
    ;;
esac
