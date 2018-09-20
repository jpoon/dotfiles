cd ~/Source

DISABLE_UPDATE_PROMPT=true
ZSH_THEME="powerlevel9k/powerlevel9k"

DEFAULT_USER=$USER
prompt_context() {}

# Powerline
POWERLEVEL9K_MODE='nerdfont-complete'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(root_indicator dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
POWERLEVEL9K_SHORTEN_DIR_LENGTH=2

POWERLEVEL9K_DIR_HOME_BACKGROUND='09'
POWERLEVEL9K_DIR_DEFAULT_BACKGROUND='09'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_BACKGROUND='009'
POWERLEVEL9K_DIR_HOME_FOREGROUND='236'
POWERLEVEL9K_DIR_DEFAULT_FOREGROUND='236'
POWERLEVEL9K_DIR_HOME_SUBFOLDER_FOREGROUND='236'

POWERLEVEL9K_COLOR_SCHEME='dark'
POWERLEVEL9K_HIDE_BRANCH_ICON=true

# Env
export EDITOR='vim'
export PATH=$PATH:/usr/local/bin

#   Go
export GOROOT="$(brew --prefix golang)/libexec"
export GOPATH=$HOME/.go
export PATH=$PATH:$GOROOT/bin

#   Nvm
export NVM_DIR=$HOME/.nvm
alias load-nvm-completion='[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
alias load-nvm='[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && loadnvmcompletion'

#   Java
export JAVA_HOME="$(/usr/libexec/java_home)"
export M2_HOME=/usr/local/Cellar/maven/3.5.2/libexec
export PATH=$PATH:$M2_HOME/bin

# Completion
autoload -U +X compinit && compinit
source <(kubectl completion zsh)

# Zsh
plugins=(
  vi-mode 
  tmux 
)

ZSH_TMUX_AUTOSTART=true

export ZSH=$HOME/.oh-my-zsh
source $ZSH/oh-my-zsh.sh
