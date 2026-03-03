# User bin first
export PATH="$HOME/bin:$PATH"

# Homebrew (Mac ARM + Intel). Only add if exists.
[[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:$PATH"
[[ -d /usr/local/bin ]] && export PATH="/usr/local/bin:$PATH"
