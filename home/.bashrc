##bashrc, debian, machiner, others

#ssh-agent.service
export SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent.socket

case $- in
    *i*) ;;
      *) return;;
esac
export TZ="America/New_York"
export VISUAL=nano
export EDITOR="$VISUAL"
export PROMPT_COMMAND='LAST_COMMAND_EXIT=$? && history -a && test 127 -eq $LAST_COMMAND_EXIT && head -n -2 $HISTFILE >${HISTFILE}_temp && mv ${HISTFILE}_temp $HISTFILE'
#export PAGER='less -e'
export HISTCONTROL=ignoreboth:erasedups:ignorespace
export HISTSIZE=5000
export HISTFILESIZE=10000
export HISTIGNORE='&:[ ]*:ls:ll:l:la:[bf]g:nap:fetcher:again:cl:burn:apps:wicn:weather:aliases:wr:frank:update:updoogie:deb:killtunes:tunes:hg:upgrade:history:h:cpf:otto:obr:auto:htop:src:clear:sync:cd:cl:exit:mkpwd:pphrase'
export HISTTIMEFORMAT="%d/%m/%y %T "
shopt -s checkwinsize
shopt -s histappend
shopt -s extglob
set -o notify
# color variables used by .bash_functions and prompts
[ -f ~/.bashcolors ] && . ~/.bashcolors
# colored man pages: groff must emit overstrikes (not SGR) for less to
# re-color them via the termcap overrides below; GROFF_NO_SGR forces that.
export GROFF_NO_SGR=1
export LESS_TERMCAP_mb=$'\e[1;31m'      # begin blink (rarely used)
export LESS_TERMCAP_md=$'\e[1;34m'      # begin bold -> blue section headers
export LESS_TERMCAP_me=$'\e[0m'         # end bold
export LESS_TERMCAP_so=$'\e[01;33m'     # begin standout (search hits) -> yellow
export LESS_TERMCAP_se=$'\e[0m'         # end standout
export LESS_TERMCAP_us=$'\e[4;32m'      # begin underline -> green
export LESS_TERMCAP_ue=$'\e[0m'         # end underline
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac
force_color_prompt=yes
if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    color_prompt=yes
    else
    color_prompt=
    fi
fi
if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt
# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac
# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
if [[ -f "/usr/lib/mc/mc-wrapper.sh" ]]; then
  alias mcc='builtin source /usr/lib/mc/mc-wrapper.sh'
  alias mc='builtin source /usr/lib/mc/mc-wrapper.sh --nosubshell'
fi
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
# Declare an associative array for directory locations (with alternatives)
# NOTE: These aliases are case sensitive where lower case is the local user
#       directory and upper case is the global system directory
declare -A ALIASES=(
    ["autostart"]="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
    ["bin"]="${HOME}/.local/bin"
    ["BIN"]="/usr/bin"
    ["cache"]="${XDG_CACHE_HOME:-${HOME}/.cache}"
    ["config"]="${XDG_CONFIG_HOME:-${HOME}/.config}"
    ["CONFIG"]="/etc"
    ["desktop"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir DESKTOP || echo "${HOME}/Desktop")"
    ["docs"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir DOCUMENTS || echo "${HOME}/Documents")"
    ["documents"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir DOCUMENTS || echo "${HOME}/Documents")"
    ["DOCS"]="/usr/local/man /usr/local/share/man /usr/share/man"
    ["downloads"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir DOWNLOAD || echo "${HOME}/Downloads")"
    ["fonts"]="${XDG_DATA_HOME:-$HOME/.local/share}/fonts ${HOME}/.fonts"
    ["FONTS"]="/usr/share/fonts"
    ["icons"]="${XDG_DATA_HOME:-$HOME/.local/share}/icons ${HOME}/.icons"
    ["ICONS"]="/usr/share/icons"
    ["music"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir MUSIC || echo "${HOME}/Music")"
    ["pics"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir PICTURES || echo "${HOME}/Pictures")"
    ["pictures"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir PICTURES || echo "${HOME}/Pictures")"
    ["share"]="${XDG_DATA_HOME:-${HOME}/.local/share}"
    ["SHARE"]="/usr/share"
    ["shortcuts"]="${XDG_DATA_HOME:-${HOME}/.local/share}/applications ${HOME}/.gnome/apps"
    ["SHORTCUTS"]="/usr/share/applications /usr/local/share/applications"
    ["themes"]="${HOME}/.themes ${XDG_DATA_HOME:-${HOME}/.local/share}/themes"
    ["THEMES"]="/usr/share/themes"
    ["tmp"]="${HOME}/tmp ${XDG_CACHE_HOME:-${HOME}/.cache}/tmp ${XDG_CACHE_HOME:-${HOME}/.cache}"
    ["TMP"]="${TMPDIR:-/tmp}"
    ["videos"]="$(command -v xdg-user-dir > /dev/null && xdg-user-dir VIDEOS || echo "${HOME}/Videos")"
    ["wallpaper"]="${XDG_DATA_HOME:-${HOME}/.local/share}/wallpapers"
    ["WALLPAPER"]="/usr/share/backgrounds /usr/share/wallpapers"
    ["web"]="/srv/http /var/www/html /usr/share/nginx/html /opt/lampp/htdocs /usr/local/apache2/htdocs /usr/local/www/apache24/data"
)
# Save original IFS and set it to space for parsing directories
OLD_IFS="${IFS}"
IFS=' '
# Loop through the associative array and create aliases and exports for existing directories
for ALIAS in "${!ALIASES[@]}"; do
    DIRECTORIES=(${ALIASES[$ALIAS]})
    for DIRECTORY in "${DIRECTORIES[@]}"; do
        if [[ -d $DIRECTORY ]]; then
            alias "${ALIAS}"="cd \"${DIRECTORY}\""
            export "${ALIAS}"="${DIRECTORY}"
            break # Only set the first found directory
        fi
    done
done
# Restore original IFS
IFS="${OLD_IFS}"
# Clean up
unset OLD_IFS DIRECTORY DIRECTORIES ALIAS ALIASES

# Display disk space available and show file system type
if hascommand --strict duf; then
    alias lll='duf -only local'
elif hascommand --strict vizex; then
    alias lll='vizex'
else
    if hascommand --strict grc; then
        alias lll='colourify \df --human-readable --print-type --exclude-type=squashfs --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=efivarfs'
    else
        alias lll='command df --human-readable --print-type --exclude-type=squashfs --exclude-type=tmpfs --exclude-type=devtmpfs --exclude-type=efivarfs'
    fi
fi
eval "$(starship init bash)"
source ~/bin/lscolors.sh
ulimit -n 4096

# opencode (idempotent: opencode injects its own bin dir when it spawns a shell)
case ":$PATH:" in
  *":$HOME/.opencode/bin:"*) ;;
  *) export PATH="$HOME/.opencode/bin:$PATH" ;;
esac
