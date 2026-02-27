#-------------------------------------------------------------
# zsh extra settings
#-------------------------------------------------------------

setopt RM_STAR_WAIT              # Wait when typing `rm *` before being able to confirm
setopt NO_BEEP                   # Don't beep on errors in ZLE
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_NO_STORE             # Remove the history (fc -l) command from the history.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt completealiases
setopt always_to_end
setopt list_ambiguous
export HISTSIZE=100000 # big big history
export HISTFILESIZE=100000 # big big history
unsetopt hup
unsetopt list_beep
skip_global_compinit=1
zstyle ':completion:*' hosts off

# Set Up and Down arrow keys to the (zsh-)history-substring-search plugin
# `-n` means `not empty`, equivalent to `! -z`
[[ -n "${terminfo[kcuu1]}" ]] && bindkey "${terminfo[kcuu1]}" history-substring-search-up
[[ -n "${terminfo[kcud1]}" ]] && bindkey "${terminfo[kcud1]}" history-substring-search-down

# Uncomment this to set the history search to match the prefix. It's used in the zsh-history-substring-search plugin,
# and it just checks if this variable is defined, not what the value is.
# export HISTORY_SUBSTRING_SEARCH_PREFIXED=true

# This speeds up pasting w/ autosuggest
# https://github.com/zsh-users/zsh-autosuggestions/issues/238
pasteinit() {
  OLD_SELF_INSERT=${${(s.:.)widgets[self-insert]}[2,3]}
  zle -N self-insert url-quote-magic # I wonder if you'd need `.url-quote-magic`?
}
pastefinish() {
  zle -N self-insert $OLD_SELF_INSERT
}
zstyle :bracketed-paste-magic paste-init pasteinit
zstyle :bracketed-paste-magic paste-finish pastefinish

# ls after every cd
function chpwd() {
 emulate -L zsh
 ls
}


# git add ci and push
function git_prepare() {
   if [ -n "$BUFFER" ]; then
	BUFFER="git add -u && git commit -m \"$BUFFER\" "
   fi

   if [ -z "$BUFFER" ]; then
	BUFFER="git add -u && git commit -v "
   fi

   zle accept-line
}
zle -N git_prepare
bindkey -r "^G"
bindkey "^G" git_prepare

explain () {
  if [ "$#" -eq 0 ]; then
    while read  -p "Command: " cmd; do
      curl -Gs "https://www.mankier.com/api/explain/?cols="$(tput cols) --data-urlencode "q=$cmd"
    done
    echo "Bye!"
  elif [ "$#" -eq 1 ]; then
    curl -Gs "https://www.mankier.com/api/explain/?cols="$(tput cols) --data-urlencode "q=$1"
  else
    echo "Usage"
    echo "explain                  interactive mode."
    echo "explain 'cmd -o | ...'   one quoted command to explain it."
  fi
}

extract () {
   if [ -f $1 ] ; then
       case $1 in
           *.tar.bz2)   tar xvjf $1    ;;
           *.tar.gz)    tar xvzf $1    ;;
           *.bz2)       bunzip2 $1     ;;
           *.rar)       unrar x $1       ;;
           *.gz)        gunzip $1      ;;
           *.tar)       tar xvf $1     ;;
           *.tbz2)      tar xvjf $1    ;;
           *.tgz)       tar xvzf $1    ;;
           *.zip)       unzip $1       ;;
           *.Z)         uncompress $1  ;;
           *.7z)        7z x $1        ;;
           *)           echo "don't know how to extract '$1'..." ;;
       esac
   else
       echo "'$1' is not a valid file!"
   fi
 }

#-------------------------------------------------------------
# Audit logger — bash command logging
#-------------------------------------------------------------
_AL_CMD_LOG_DIR=""
_AL_SESSION_ID=""

_al_preexec() {
    [[ -z "$_AL_CMD_LOG_DIR" ]] && return
    local ts="$(date -Iseconds)"
    local cwd="$(pwd)"
    echo "[${ts}] [${_AL_SESSION_ID}] (${cwd}) $1" >> "${_AL_CMD_LOG_DIR}/commands.log"
    printf '{"ts":"%s","session":"%s","cwd":"%s","command":"%s"}\n' "$ts" "$_AL_SESSION_ID" "$cwd" "$(echo "$1" | sed 's/"/\\"/g')" >> "${_AL_CMD_LOG_DIR}/commands.jsonl"
}

start_cmd_log() {
    local project_dir="${1:?Usage: start_cmd_log /path/to/project}"
    project_dir="$(realpath "$project_dir")"
    _AL_CMD_LOG_DIR="${project_dir}/.audit"
    _AL_SESSION_ID="$$_$(head -c4 /dev/urandom | xxd -p)"
    mkdir -p "$_AL_CMD_LOG_DIR"
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec _al_preexec
    echo "[*] Command logging started (session ${_AL_SESSION_ID}) → ${_AL_CMD_LOG_DIR}/commands.log"
}

stop_cmd_log() {
    if [[ -n "$_AL_CMD_LOG_DIR" ]]; then
        add-zsh-hook -d preexec _al_preexec
        echo "[*] Command logging stopped (was logging to ${_AL_CMD_LOG_DIR})"
        _AL_CMD_LOG_DIR=""
    else
        echo "[*] Command logging is not active"
    fi
}

# Auto-start command logging if tmux session has AL_PROJECT_DIR set
if [[ -n "${AL_PROJECT_DIR:-}" ]]; then
    start_cmd_log "$AL_PROJECT_DIR"
fi