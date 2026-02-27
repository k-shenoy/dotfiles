# At the very top of the file
CONFIG_DIR=$(dirname $(realpath ${(%):-%x}))
DOT_DIR=$CONFIG_DIR/..

# Instant prompt
export TERM="xterm-256color"

ZSH_DISABLE_COMPFIX=true
ZSH=$HOME/.oh-my-zsh

plugins=(zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search)

source $ZSH/oh-my-zsh.sh
source $CONFIG_DIR/aliases.sh
source $CONFIG_DIR/extras.sh
source $CONFIG_DIR/key_bindings.sh
add_to_path "${DOT_DIR}/custom_bins"

# for uv
if [ -d "$HOME/.local/bin" ]; then
  source $HOME/.local/bin/env
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
if [ -d "$HOME/.cargo" ]; then
  . "$HOME/.cargo/env"
fi

if [ -d "$HOME/.pyenv" ]; then
  export PYENV_ROOT="$HOME/.pyenv"
  command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"
fi

if [ -d "$HOME/.local/bin/micromamba" ]; then
  export MAMBA_EXE="$HOME/.local/bin/micromamba"
  export MAMBA_ROOT_PREFIX="$HOME/micromamba"
  __mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
  if [ $? -eq 0 ]; then
      eval "$__mamba_setup"
  else
      alias micromamba="$MAMBA_EXE"  # Fallback on help from mamba activate
  fi
  unset __mamba_setup
fi

FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "`fnm env`"
fi

if command -v ask-sh &> /dev/null; then
  export ASK_SH_OPENAI_API_KEY=$(cat $HOME/.openai_api_key)
  export ASK_SH_OPENAI_MODEL=gpt-4o-mini
  eval "$(ask-sh --init)"
fi

cat $CONFIG_DIR/start.txt

export PATH="$HOME/bin:$PATH"

# Add these to /workspace-vast/keshavs/dotfiles/config/zshrc.sh

# Interactive sessions
alias sint="srun -p dev,overflow --qos=dev --cpus-per-task=8 --gres=gpu:1 --mem=32G --job-name=D_${USER} --pty zsh"
alias sint2="srun -p dev,overflow --qos=dev --cpus-per-task=16 --gres=gpu:2 --mem=64G --job-name=D_${USER} --pty zsh"
alias sint4="srun -p dev,overflow --qos=dev --cpus-per-task=32 --gres=gpu:4 --mem=128G --job-name=D_${USER} --pty zsh"

# Queue monitoring
alias sq="squeue -u ${USER}"
alias sqa="squeue"
alias sqw="watch -n 2 squeue -u ${USER}"
alias sacct-today="sacct -u ${USER} --starttime=today --format=JobID,JobName,Partition,QOS,Elapsed,State,ExitCode"

# Job details
alias sjob="scontrol show job"

# Cancel jobs
alias sc="scancel"
alias scall="scancel -u ${USER}"

# GPU monitoring
alias gpuwatch="watch -n 1 nvidia-smi"

# Job log viewing
alias tailj='_tailj(){ tail -f logs/*_$1.out; }; _tailj'
alias catj='_catj(){ cat logs/*_$1.out; }; _catj'
alias lslogs='ls -lht logs/ | head -20'
alias lastlog='ls -t logs/*.out | head -1 | xargs tail -f'  # Tail most recent log

# Propensity-awareness queue scripts
PA_SCRIPTS=/workspace/exploration_hacking/src/static_bash_scripts
rq() { $PA_SCRIPTS/run_queue.sh "$@"; }

stick-title() {
    export TMUX_PANE_TITLE="$*"
    tmux select-pane -T "$*"
}

unstick-title() {
    unset TMUX_PANE_TITLE
}

# Hook that runs after oh-my-zsh's
add-zsh-hook precmd _restore_pane_title
_restore_pane_title() {
    if [[ -n "$TMUX_PANE_TITLE" ]]; then
        tmux select-pane -T "$TMUX_PANE_TITLE"
    fi
}
