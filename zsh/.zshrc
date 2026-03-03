[[ -o interactive ]] || return

# Load portable config
if [[ -r "$HOME/.config/zsh/zshrc.common" ]]; then
  source "$HOME/.config/zsh/zshrc.common"
fi

# OS-specific overlays
case "$(uname -s)" in
  Darwin)
    [[ -r "$HOME/.config/zsh/zshrc.darwin" ]] && source "$HOME/.config/zsh/zshrc.darwin"
    ;;
  Linux)
    [[ -r "$HOME/.config/zsh/zshrc.linux" ]] && source "$HOME/.config/zsh/zshrc.linux"
    ;;
esac
