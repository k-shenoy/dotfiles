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

# mkipynb /path/to/file.json  ->  /path/to/file.ipynb
mkipynb() {
  local src="$1"
  if [[ -z "$src" ]]; then
    echo "usage: mkipynb <path/to/file>"; return 1
  fi
  if [[ ! -e "$src" ]]; then
    echo "mkipynb: no such file: $src"; return 1
  fi

  # sanitize any accidental newlines/CRs from pasted paths
  src="${src//$'\n'/}"
  src="${src//$'\r'/}"

  /usr/bin/env python3 - "$src" <<'PY'
import json, sys, pathlib

src = pathlib.Path(sys.argv[1]).expanduser().resolve()
nb_path = src.with_suffix(".ipynb")

# Default code with safe quoting of the path
path_literal = json.dumps(src.as_posix())
cell_code = [
    "from src.utils.utils import load_json\n",
    f"k = load_json({path_literal})\n",
    "print(len(k))\n",
]

nb_json = {
    "cells": [{
        "cell_type": "code",
        "metadata": {},
        "source": cell_code,
        "execution_count": None,
        "outputs": []
    }],
    "metadata": {
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python"}
    },
    "nbformat": 4,
    "nbformat_minor": 5
}

if nb_path.exists():
    print(str(nb_path))  # don't overwrite; still print the path
    sys.exit(2)

nb_path.write_text(json.dumps(nb_json, ensure_ascii=False, indent=1), encoding="utf-8")
print(str(nb_path))
PY
}

