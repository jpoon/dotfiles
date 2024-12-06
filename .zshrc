cd ~/Source/

DISABLE_UPDATE_PROMPT=true
ZSH_THEME="powerlevel9k/powerlevel9k"

setopt +o nomatch

DEFAULT_USER=$USER
prompt_context() {}

DISABLE_UNTRACKED_FILES_DIRTY=1

# Powerline
POWERLEVEL9K_MODE='nerdfont-complete'
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(root_indicator dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(virtualenv)
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
export PATH=$PATH:/usr/local/bin:/usr/local/opt
export GPG_TTY=$(tty)
export ZSH=$HOME/.oh-my-zsh

#   Go
#export GOROOT="$(brew --prefix golang)/libexec"
#export GOPATH=$HOME/.go
#export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

#   Nvm
#export NVM_DIR="$HOME/.nvm"
#alias load-nvm='[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"'
#alias load-nvm-completion='[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"'

#   Java
export JAVA_HOME="$(/usr/libexec/java_home)"
export M2_HOME=/usr/local/Cellar/maven/3.5.4/libexec
export PATH=$PATH:$M2_HOME/bin

#   Python
export PATH="/usr/local/opt/python/libexec/bin:$PATH"

#   Brew
export PATH="/usr/local/sbin:$PATH"

#   Hurl
export HURL_PATH=$HOME/Source/hurl/hurl
export PATH=$PATH:$HURL_PATH

# Completion
autoload -U +X compinit && compinit

# Aliases
yksa() {
    if [[ $1 == "-f" ]]
    then
        rm -f ~/.ssh/ssh_auth_sock
    fi

    export SSH_AUTH_SOCK="$(< ~/.ssh/ssh_auth_sock)"
    # if cached agent socket is invalid, start a new one
    [ -S "$SSH_AUTH_SOCK" ] || {
        killall -9 ssh-agent
        killall -9 ssh-pkcs11-helper

        eval "$(ssh-agent)"

        ssh-add -s /usr/local/lib/opensc-pkcs11-local.so # yubikey
        ssh-add /Users/jaspoon/.ssh/id_rsa # bitbucket
        ssh-add /Users/jaspoon/Source/vmi-dataplane-testing/test/docker/ssh/id_rsa # canary test

        echo $SSH_AUTH_SOCK > ~/.ssh/ssh_auth_sock
        #export SSH_AUTH_SOCK=~/.ssh/auth_sock
    }
}
source ~/Source/compute-ops/scripts/opc.sh
eval "$(~/Source/compute-console-tools/aliases.sh)"
alias ops='cd $HOME/Source/compute-ops && git pull && make venv3 && . venv3/bin/activate'
alias uncolor='sed -E "s/ ?\[[0-9;]+m//g"'
alias mcafee_stop='sudo /usr/local/McAfee/AntiMalware/VSControl stop; sudo /usr/local/McAfee/AntiMalware/VSControl stopoas'
alias mcafee_start='sudo /usr/local/McAfee/AntiMalware/VSControl start; sudo /usr/local/McAfee/AntiMalware/VSControl startoas'

# Zsh
plugins=(
  vi-mode 
  #tmux 
  mvn
  virtualenv
)

#ZSH_TMUX_AUTOSTART=true

source $ZSH/oh-my-zsh.sh

## pic-tools
source /Users/jaspoon/Source/pic-tools/scripts/*.env
source /Users/jaspoon/Source/tools/vpn/vpn.sh

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
