#  ---------------------------------------------------------------------------
#
#  Shell Aliases
#  Cross-platform (macOS + Linux) — sourced by zshrc.common
#
#  Sections:
#    1.  General
#    2.  Navigation
#    3.  File listing
#    4.  Editor
#    5.  Git
#    6.  Networking
#    7.  System
#
#  ---------------------------------------------------------------------------


#  ---------------------------------------------------------------------------
#  1.  General
#  ---------------------------------------------------------------------------

alias c='clear'
alias h='history'
alias p='pwd'
alias mkdir='mkdir -pv'                                         # create intermediate dirs automatically
alias grep='grep --color=auto'
alias path='echo -e "${PATH//:/\\n}"'                          # print each PATH entry on its own line
alias reload='exec zsh'                                        # reload shell in place


#  ---------------------------------------------------------------------------
#  2.  Navigation
#  ---------------------------------------------------------------------------

alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../../..'
alias .5='cd ../../../../..'
alias .6='cd ../../../../../..'


#  ---------------------------------------------------------------------------
#  3.  File listing
#  ---------------------------------------------------------------------------

if [[ "$(uname -s)" == "Darwin" ]]; then
  alias ls='ls -G'
else
  alias ls='ls --color=auto'
fi

alias l='ls -1'
alias ll='ls -lh'
alias la='ls -lAh'
alias lt='ls -lht'                                             # sort by modified time
alias lsd='ls -l | grep "^d"'                                 # list directories only
alias less='less -R'                                           # always show colour in less


#  ---------------------------------------------------------------------------
#  4.  Editor
#  ---------------------------------------------------------------------------

alias v='nvim'
alias vi='nvim'


#  ---------------------------------------------------------------------------
#  5.  Git
#  ---------------------------------------------------------------------------

alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gad='git add .'
alias gb='git branch'
alias gbd='git branch -d'
alias gbr='git branch -r'
alias gbs='git branch -a'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gd='git diff'
alias gdh='git diff HEAD'
alias gds='git diff --staged'
alias gf='git fetch'
alias gi='git init'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'
alias glp="git log --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
alias gm='git merge'
alias gp='git push'
alias gpo='git push -u origin'
alias gpl='git pull'
alias grb='git rebase'
alias grbi='git rebase -i'
alias grh='git reset HEAD'                                     # unstage files
alias grhh='git reset --hard HEAD^'                           # roll back to last commit (destructive)
alias grsh='git reset --soft HEAD^'                           # roll back to staged
alias grs='git remote -v'
alias gs='git status -sb'
alias gst='git stash'
alias gstp='git stash pop'
alias gt='git tag'


#  ---------------------------------------------------------------------------
#  6.  Networking
#  ---------------------------------------------------------------------------

alias ping='ping -c 5'                                         # limit to 5 packets by default
alias myip='curl -s https://api.ipify.org && echo'            # public-facing IP address
alias lsock='sudo lsof -i -P'                                 # all open sockets
alias lsockT='sudo lsof -nP | grep TCP'                       # open TCP sockets only
alias lsockU='sudo lsof -nP | grep UDP'                       # open UDP sockets only
alias openPorts='sudo lsof -i | grep LISTEN'                  # all listening ports


#  ---------------------------------------------------------------------------
#  7.  System
#  ---------------------------------------------------------------------------

alias memhogs='ps aux | sort -rk 4 | head -10'    # top memory consumers (sort by %MEM)
alias cpuhogs='ps aux | sort -rk 3 | head -10'   # top CPU consumers (sort by %CPU)
