# ${@: -1}         - last passed argument
# ${@:1:$(($#-1))} - all arguments except last one

# Source other bash configuration files
[ -f ~/.bashrc ] && . ~/.bashrc
[ -f ~/.bash_aliases ] && . ~/.bash_aliases
[ -f ~/.bash_local ] && . ~/.bash_local

# Configure shell
shopt -s cdspell
shopt -s checkwinsize
shopt -s dirspell
shopt -s histappend

# Brew and local changes
export PATH="/usr/local/sbin:/usr/local/bin:~/bin:~/go/bin:$PATH"

# Krew
export PATH="${PATH}:${HOME}/.krew/bin"

eval "$(pyenv init -)"


#-------------------------------------------------------------------------------
# Autocompletion
#-------------------------------------------------------------------------------

# BREW_PREFIX=$(brew --prefix)
BREW_PREFIX=/usr/local

# Generic bash
if [ -f $BREW_PREFIX/share/bash-completion/bash_completion ]; then
    source $BREW_PREFIX/share/bash-completion/bash_completion
fi

# Program specific
if type brew 2&>/dev/null; then
  for completion_file in $BREW_PREFIX/etc/bash_completion.d/*; do
    source "$completion_file"
  done
fi

# minicube
if [ ! -f $BREW_PREFIX/etc/bash_completion.d/minikube ]; then
    type minikube 2&>/dev/null && source <(minikube completion bash)
fi

# kubectl
if [ ! -f $BREW_PREFIX/etc/bash_completion.d/kubectl ]; then
    type kubectl 2&>/dev/null  && source <(kubectl completion bash)
fi

# gcloud
#. /usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/completion.bash.inc

# aliases
for _a in $(sed '/^alias /!d;s/^alias //;s/=.*$//' ~/.bash_aliases); do
  complete -F _complete_alias "$_a"
done

#-------------------------------------------------------------------------------
# Functions
#-------------------------------------------------------------------------------

function S() {
    # ${@: -1}         - last passed argument
    # ${@:1:$(($#-1))} - all arguments except last one

    sshcmd="ssh -o StrictHostKeyChecking=no -t";
    ! [[ ${@: -1} =~ ^- ]] && [ $# -gt 1 ] && $sshcmd ${@:1:$(($#-1))} "sudo bash -c '${@: -1}'" || $sshcmd $@ "cat /etc/motd 2>/dev/null; sudo PASSED_PARAMS=\"$(cat ~/.bash_profile_remote)\" PROMPT_COMMAND=\"eval \\\"\\\$PASSED_PARAMS\\\"; unset PROMPT_COMMAND\" bash -l";
}

# function s() {
#     sshcmd="ssh -o StrictHostKeyChecking=no -t";
#     ! [[ ${@: -1} =~ ^- ]] && [ $# -gt 1 ] && $sshcmd ${@:1:$(($#-1))} "sudo bash -c '${@: -1}'" || $sshcmd $@ "cat /etc/motd; PASSED_PARAMS=\"$(cat ~/.bash_profile_remote)\" PROMPT_COMMAND=\"eval \\\"\\\$PASSED_PARAMS\\\"; unset PROMPT_COMMAND\" bash -l";
# }


function RD() {
    REMOTE_HOST=${1:-ansible@7b-stg-swarm02.mps.lan}
    ps -ef | awk '/[d]ocker.sock/ {print $2}' | xargs kill
    ssh -f -N -L ~/.docker/remoteDocker.sock:/var/run/docker.sock ${REMOTE_HOST}
    export DOCKER_HOST=unix://$HOME/.docker/remoteDocker.sock
}

function sp() {
    ssh -o ProxyCommand="ssh bastion.host -p 18473 -W %h:%p" $@
}

function getTTL() {
    sysctl net.inet.ip.ttl
}

function increaseTTL() {
    sudo sysctl -w net.inet.ip.ttl=$(sysctl net.inet.ip.ttl | awk '{print $NF+1}')
}

function decreaseTTL() {
    sudo sysctl -w net.inet.ip.ttl=$(sysctl net.inet.ip.ttl | awk '{print $NF-1}')
}

function kh() {
    cat ~/.ssh/known_hosts | cut -f1 -d' ' | tr ',' '\n' | sort -n | grep --color $1
}

function dkh() {
    sed -i '.bak' '/[[:<:]]'$1'[[:>:]]/d' ~/.ssh/known_hosts
}

function socks() {
    networksetup -setsocksfirewallproxystate Wi-Fi $1
}

# Retrieve Virtual Host certificate
function getHostCert() {
    # getHostCert api.preprod.fusionfabric.cloud 40.85.126.186 443
    # getHostCert api.preprod.fusionfabric.cloud 40.85.126.186:443
    # getHostCert api.preprod.fusionfabric.cloud 40.85.126.186
    # getHostCert api.preprod.fusionfabric.cloud
    local virtual_host=$1
    local server_addr=$2
    local server_port=$3
    [ "$server_addr" = "" ] && server_addr=$virtual_host
    [ "$server_port" == "" ] && server_port=$(echo $server_addr| awk -F':' '{print $2}')
    [ "$server_port" == "" ] && server_port=443
    (set -x && \
        openssl s_client -showcerts -servername $virtual_host -connect $server_addr:$server_port </dev/null)
}

# Curl VirtualHost on IP
function curlHost() {
    # curlHost https://domain.com/status 8.8.8.8 443
    # curlHost https://api.preprod.fusionfabric.cloud 8.8.8.8:443
    # curlHost https://api.preprod.fusionfabric.cloud 40.85.126.186
    # curlHost https://api.preprod.fusionfabric.cloud
    local url=$1
    local server_host_port=$2
    local server_port=$3

    local virtual_host_port=$(echo "$url" | sed -E 's|^https?://||' | awk -F'/' '{print $1}')
    local virtual_host=$(echo "$virtual_host_port" | awk -F ':' '{print $1}')

    [ "$server_host_port" = "" ] && server_host_port=$virtual_host_port
    local server_addr=$(echo "$server_host_port" | awk -F ':' '{print $1}')

    [ "$server_port" == "" ] && server_port=$(echo "$server_host_port" | awk -F ':' '{print $2}')
    [ "$server_port" == "" ] && server_port=443

    (set -x && \
        curl -vso /dev/null --resolve $virtual_host:$server_port:$server_addr $url)
}



# Port forwarding
function pfwd() {
    if [ $# -eq 3 ]; then
        # pfwd 192.168.1.133:9200 11.12.13.14:9200 192.168.1.3
        # pfwd :9200 11.12.13.14:9200 192.168.1.3
        # pfwd :9200 :9200 192.168.1.3
        shost=$3
        rhost=$(echo $2 | cut -f1 -d':')
        rport=$(echo $2 | cut -f2- -d':')
        lhost=$(echo $1 | cut -f1 -d':')
        lport=$(echo $1 | cut -f2- -d':')
        [ "x$rhost" = "x" ] && rhost='127.0.0.1'
        [ "x$rport" = "x" ] && echo "require port" && break
        [ "x$lhost" = "x" ] && lhost='127.0.0.1'
        [ "x$lport" = "x" ] && lport=$rport
    elif [ $# -eq 2 ]; then
        if [ $(echo $2 | grep ':' | wc -l) -eq 0 ]; then
            # pfwd 11.12.13.14:9200 192.168.1.3
            # pfwd :9200 192.168.1.3
            shost=$2
            rhost=$(echo $1 | cut -f1 -d':')
            rport=$(echo $1 | cut -f2- -d':')
            [ "x$rhost" = "x" ] && rhost='127.0.0.1'
            [ "x$rport" = "x" ] && echo "require port" && break
            lhost='127.0.0.1'
            lport=$rport
        else
            # pfwd 192.168.1.133:9200 192.1268.1.3:9200
            # pfwd :9200 192.1268.1.3:9200
            rhost=$(echo $2 | cut -f1 -d':')
            rport=$(echo $2 | cut -f2- -d':')
            lhost=$(echo $1 | cut -f1 -d':')
            lport=$(echo $1 | cut -f2- -d':')
            [ "x$rhost" = "x" ] && echo "require host" && break
            [ "x$rport" = "x" ] && echo "require port" && break
            [ "x$lhost" = "x" ] && lhost='127.0.0.1'
            [ "x$lport" = "x" ] && lport=$rport
            shost=$rhost
        fi
    elif [ $# -eq 1 ]; then
        # pfwd 192.168.1.3:9200
        rhost=$(echo $1 | cut -f1 -d':')
        rport=$(echo $1 | cut -f2- -d':')
        [ "x$rhost" = "x" ] && echo "require host" && break
        [ "x$rport" = "x" ] && echo "require port" && break
        shost=$rhost
        lhost='127.0.0.1'
        lport=$rport
    fi
    echo ssh -f -N -L $lhost:$lport:$rhost:$rport $shost
}

function pls() {
    local clNorm="\e[0m"
    local clRed="\x1B[01;91m"
    local clGreen="\x1B[01;32m"
    local clYellow="\x1B[01;93m"

    local lst=$(ps auxww | grep ssh | grep '\-L' | sed -e 's/^[a-zA-Z.]*[[:blank:]]*\([0-9]*\).*-L \([0-9a-zA-Z.-]*:[0-9a-z.-]*:[0-9a-z.-]*:[0-9a-z.-]*\) \([a-zA-Z0-9@.-]*\).*/\1 \2 \3/g')
    echo -e "${clRed}PID\t${clGreen}Forwarded Ports\t\t\t${clYellow}Remote Host${clNorm}"
    while read PID FRWD HOST; do
        echo -e "${clRed}${PID}\t${clGreen}${FRWD}\t${clYellow}${HOST}${clNorm}"
    done <<< "$lst"
}

function man() {
    env LESS_TERMCAP_mb=$'\E[01;31m' \
    LESS_TERMCAP_md=$'\E[01;38;5;74m' \
    LESS_TERMCAP_me=$'\E[0m' \
    LESS_TERMCAP_se=$'\E[0m' \
    LESS_TERMCAP_so=$'\E[38;5;246m' \
    LESS_TERMCAP_ue=$'\E[0m' \
    LESS_TERMCAP_us=$'\E[04;38;5;146m' \
    man "$@"
}


#-------------------------------------------------------------------------------
# Variables
#-------------------------------------------------------------------------------

complete -cf sudo
HISTCONTROL=ignoredups:ignorespace
HISTFILESIZE=9000
HISTSIZE=9000
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S :: "
PROMPT_COMMAND='history -a'
export CLICOLOR=1
export CLICOLOR_FORCE=1
export GREP_OPTIONS='--color=auto'
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export ITERM2_SQUELCH_MARK=1
export LSCOLORS=ExFxCxDxBxegedabagacad


#-------------------------------------------------------------------------------
# All Aliases
#-------------------------------------------------------------------------------

alias .....='cd ../../../..'
alias ....='cd ../../..'
alias ...='cd ../..'
alias ..='cd ..'
alias cat='bat --decorations=never --theme OneHalfDark --paging=never'
alias dec='docker exec -ti'
alias dps='docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias gmtr='mtr 8.8.8.8'
alias grep='grep --color'
alias hideFiles='defaults write com.apple.finder AppleShowAllFiles NO;  killall Finder /System/Library/CoreServices/Finder.app'
alias less='less -R'
alias ll='ls -lahGF'
alias ls='ls -G'
alias myip='dig +short myip.opendns.com @resolver1.opendns.com'
alias ncdu='ncdu --color dark -x'
alias pgw="ping -c3 $(netstat -rn | grep default | head -1 | grep -v ':' | awk '{print $2}')"
alias pping='prettyping --nolegend'
alias preview="fzf --preview 'bat --color \"always\" {}'"
alias showFiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder /System/Library/CoreServices/Finder.app'
alias sshpass='ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no'
alias subl='"/Applications/Sublime Text.app/Contents/SharedSupport/bin/subl"'


#-------------------------------------------------------------------------------
# Git
#-------------------------------------------------------------------------------

alias gad='git add'
alias gada='git add -A'
alias gbr='git branch'
alias gci='git commit'
alias gco='git checkout'
alias gdf='git diff'
alias gg='git grep'
alias glg2='git log --date-order --all --graph --name-status --format="%C(green)%H%Creset %C(yellow)%an%Creset %C(blue bold)%ar%Creset %C(red bold)%d%Creset%s"'
alias glg='git log --date-order --all --graph --format="%C(green)%h%Creset %C(yellow)%an%Creset %C(blue bold)%ar%Creset %C(red bold)%d%Creset%s"'
alias gpl='git pull'
alias gpu='git push'
alias grb='git rebase'
alias gst='git status'


#-------------------------------------------------------------------------------
# GBT
#-------------------------------------------------------------------------------

# Local
alias docker='gbt_docker'
alias s='gbt_ssh'
alias screen='gbt_screen'
alias ssu="gbt_sudo su -"
alias vagrant='gbt_vagrant'
source ~/.gbt/theme_local.sh
PS1='$(gbt $?)'

# Remote
export GBT__HOME="$BREW_PREFIX/opt/gbt/share/gbt"
# export GBT__HOME="$BREW_PREFIX/opt/gbt-git/share/gbt-git"
export GBT__PLUGINS_REMOTE='ssh,sudo,docker'
export GBT__PLUGINS_REMOTE='ssh,sudo'
export GBT__SOURCE_COMPRESS='cat'
export GBT__SOURCE_DECOMPRESS='cat'
export GBT__SOURCE_MINIMIZE='cat'
export GBT__THEME_SSH="$HOME/.gbt/theme_remote.sh"
source "$GBT__HOME/sources/gbts/cmd/local.sh"
alias gbt___dddd='docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias gbt___s='gbt_ssh'
alias gbt___ssu='gbt_sudo su -'
