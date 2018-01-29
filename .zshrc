cd ~/Source/Vim

# Zsh
export ZSH=$HOME/.oh-my-zsh

DISABLE_UPDATE_PROMPT=true
ZSH_TMUX_AUTOSTART=true
ZSH_THEME="powerlevel9k/powerlevel9k"

DEFAULT_USER=$USER
prompt_context() {}

plugins=(
  git 
  vi-mode 
  osx 
  colored-man-pages 
  tmux 
  kubectl
)

source $ZSH/oh-my-zsh.sh

# Powerline
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
export ANDROID_HOME=$HOME/Library/Android/sdk
export GOROOT=/usr/local/opt/go/libexec
export GOPATH=$HOME/Source/go
export EDITOR='vim'
export NVM_DIR=/Users/jason/.nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

export PATH=$PATH:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/jason/Library/Android/sdk/tools:/usr/local/share/dotnet:$GOROOT/bin:$GOPATH/bin

# completion
[ -f '/usr/local/lib/azure-cli/az.completion' ] && source '/usr/local/lib/azure-cli/az.completion'

