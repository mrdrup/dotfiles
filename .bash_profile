# ${@: -1}         - last passed argument
# ${@:1:$(($#-1))} - all arguments except last one

# Source other bash configuration files
[ -f ~/.bashrc ] && . ~/.bashrc
[ -f ~/.bash_aliases ] && . ~/.bash_aliases


# Brew and local changes
export PATH="/usr/local/sbin:/usr/local/bin:~/bin:$PATH"

# # Ruby
# export PATH="$PATH:$HOME/.rbenv/bin"
# [[ `which rbenv` ]] && eval "$(rbenv init -)"

# # Python
# export PATH="$PATH:~/Library/Python/2.7/bin/"


### 
# Autocompletion
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


# COLORS
clNorm="\e[0m"
clRed="\x1B[01;91m"
clGreen="\x1B[01;32m"
clYellow="\x1B[01;93m"


# VARIABLES
export GREP_OPTIONS='--color=auto'
export CLICOLOR=1
export CLICOLOR_FORCE=1
export LSCOLORS=ExFxCxDxBxegedabagacad


function S() {
    # ${@: -1}         - last passed argument
    # ${@:1:$(($#-1))} - all arguments except last one

    sshcmd="ssh -o StrictHostKeyChecking=no -t";
    # ! [[ ${@: -1} =~ ^- ]] && [ $# -gt 1 ] && $sshcmd ${@:1:$(($#-1))} "sudo bash -c '${@: -1}'" || $sshcmd $@ "cat /etc/motd; sudo -i";
    ! [[ ${@: -1} =~ ^- ]] && [ $# -gt 1 ] && $sshcmd ${@:1:$(($#-1))} "sudo bash -c '${@: -1}'" || $sshcmd $@ "cat /etc/motd 2>/dev/null; sudo PASSED_PARAMS=\"$(cat ~/.bash_profile_remote)\" PROMPT_COMMAND=\"eval \\\"\\\$PASSED_PARAMS\\\"; unset PROMPT_COMMAND\" bash -l";
}

# function s() {
#     sshcmd="ssh -o StrictHostKeyChecking=no -t";
#     ! [[ ${@: -1} =~ ^- ]] && [ $# -gt 1 ] && $sshcmd ${@:1:$(($#-1))} "sudo bash -c '${@: -1}'" || $sshcmd $@ "cat /etc/motd; PASSED_PARAMS=\"$(cat ~/.bash_profile_remote)\" PROMPT_COMMAND=\"eval \\\"\\\$PASSED_PARAMS\\\"; unset PROMPT_COMMAND\" bash -l";
# }

# function Sg() {
#     sshcmd="ssh -o StrictHostKeyChecking=no -t";
#     $sshcmd $@ "cat /etc/motd 2>/dev/null; GBT_CONF=\"/tmp/.gbt.$RANDOM\" && echo \"GBT_CONF=\$GBT_CONF\" >> \$GBT_CONF && echo \"$(cat ~/.gbt.ssh)\" >> \$GBT_CONF && echo \"PS1='$(source ~/.gbt.ssh; gbt)'\" >> \$GBT_CONF && sudo bash --rcfile \$GBT_CONF -i; rm -f \$GBT_CONF"
# }

# function sg() {
#     sshcmd="ssh -o StrictHostKeyChecking=no -t";
#     $sshcmd $@ "
#         cat /etc/motd 2>/dev/null;
#         GBT_CONF=\"/tmp/.gbt.$RANDOM\";
#         echo \"$(cat ~/.gbt.ssh)\" > \$GBT_CONF &&
#         echo \"PS1='$(source ~/.gbt.ssh; gbt)'\" >> \$GBT_CONF &&
#         echo \"$(alias | awk '/git/ {sub(/^alias /,"", $0); print "alias "$0; exit}')\" >> \$GBT_CONF &&
#         bash --rcfile \$GBT_CONF -i;
#         rm -f \$GBT_CONF"
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
echo     ssh -f -N -L $lhost:$lport:$rhost:$rport $shost
}

pls() {
    lst=$(ps auxww | grep ssh | grep '\-L' | sed -e 's/^[a-zA-Z.]*[[:blank:]]*\([0-9]*\).*-L \([0-9a-zA-Z.-]*:[0-9a-z.-]*:[0-9a-z.-]*:[0-9a-z.-]*\) \([a-zA-Z0-9@.-]*\).*/\1 \2 \3/g')
    echo -e "${clRed}PID\t${clGreen}Forwarded Ports\t\t\t${clYellow}Remote Host${clNorm}"
    while read PID FRWD HOST; do
        echo -e "${clRed}${PID}\t${clGreen}${FRWD}\t${clYellow}${HOST}${clNorm}"
    done <<< "$lst"
}

man() {
    env LESS_TERMCAP_mb=$'\E[01;31m' \
    LESS_TERMCAP_md=$'\E[01;38;5;74m' \
    LESS_TERMCAP_me=$'\E[0m' \
    LESS_TERMCAP_se=$'\E[0m' \
    LESS_TERMCAP_so=$'\E[38;5;246m' \
    LESS_TERMCAP_ue=$'\E[0m' \
    LESS_TERMCAP_us=$'\E[04;38;5;146m' \
    man "$@"
}

complete -cf sudo
HISTCONTROL=ignoredups:ignorespace
HISTFILESIZE=10000
HISTSIZE=10000
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S :: "
PROMPT_COMMAND='history -a'
shopt -s cdspell
shopt -s checkwinsize
shopt -s dirspell
shopt -s histappend


alias .....='cd ../../../..'
alias ....='cd ../../..'
alias ...='cd ../..'
alias ..='cd ..'
alias cat='bat --decorations=never --theme OneHalfDark'
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


##  G I T

# git commamands simplified
alias gst='git status'
alias gdf='git diff'
alias gco='git checkout'
alias gci='git commit'
alias grb='git rebase'
alias gbr='git branch'
alias gad='git add'
alias gada='git add -A'
alias gpl='git pull'
alias gpu='git push'
alias glg='git log --date-order --all --graph --format="%C(green)%h%Creset %C(yellow)%an%Creset %C(blue bold)%ar%Creset %C(red bold)%d%Creset%s"'
alias glg2='git log --date-order --all --graph --name-status --format="%C(green)%H%Creset %C(yellow)%an%Creset %C(blue bold)%ar%Creset %C(red bold)%d%Creset%s"'


## R A K E
alias brake='bundle exec rake'


# if [ $(id -u) -eq 0 ]; then
#     export PS1='\[\e[1;30m\]\t`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[0;31m\] ✘ "; fi`\[\e[0;31m\]\u\[\e[0;35m\] @ \h \[\e[1;34m\]\W \$\[\e[0m\] '
# else
#     export PS1='\[\e[1;30m\]\t`if [ $? = 0 ]; then echo "\[\e[32m\] ✔ "; else echo "\[\e[0;31m\] ✘ "; fi`\[\e[0;35m\][\h] \[\e[1;32m\]\W \[\e[1;33m\]$(__git_ps1 "(%s) ")\[\e[1;32m\]>\[\e[0m\] '
# fi


#### GBT
export GBT_CARS='Time, Status, Hostname, Dir, Git, Sign'
export GBT_CAR_BG='default'
export GBT_SEPARATOR=' '

export GBT_CAR_TIME_FG='dark_gray'
export GBT_CAR_TIME_FM='bold'
export GBT_CAR_TIME_FORMAT='{{ Time }}'

export GBT_CAR_STATUS_BG='default'
export GBT_CAR_STATUS_DISPLAY='1'
export GBT_CAR_STATUS_ERROR_FG='red'
export GBT_CAR_STATUS_FORMAT='{{ Symbol }}'
export GBT_CAR_STATUS_OK_FG='green'

export GBT_CAR_HOSTNAME_ADMIN_FG='light_red'
export GBT_CAR_HOSTNAME_FG='magenta'
export GBT_CAR_HOSTNAME_FORMAT='[{{ Host }}]'
export GBT_CAR_HOSTNAME_USER_FG='light_green'
 
export GBT_CAR_DIR_FG='green'
export GBT_CAR_DIR_FM='bold'
export GBT_CAR_DIR_FORMAT='{{ Dir }}'

export GBT_CAR_GIT_FG='light_yellow'
export GBT_CAR_GIT_FM='bold'
export GBT_CAR_GIT_FORMAT='({{ Head }} {{ Status }}{{ Ahead }}{{ Behind }})'

# export GBT_CAR_EXECTIME_PRECISION=5
# export GBT_CAR_EXECTIME_FG='default'
# export GBT__SOURCE_DATE_ARG='+%s'
# source "$BREW_PREFIX/share/gbt-git/sources/exectime/bash.sh"


export GBT_CAR_SIGN_ADMIN_FG='red'
export GBT_CAR_SIGN_ADMIN_TEXT='#'
export GBT_CAR_SIGN_USER_FG='light_green'
export GBT_CAR_SIGN_USER_TEXT='>'
export GBT_CAR_SIGN_FORMAT='{{ Symbol }} '


PS1='$(gbt $?)'


# GBT Remote
export GBT__HOME="$BREW_PREFIX/share/gbt-git"
export GBT__CARS_REMOTE='Status, Os, Time, Hostname, Dir, Sign'
export GBT__PLUGINS_REMOTE='docker,screen,ssh,su,sudo'
export GBT__SOURCE_MD5_CUT_LOCAL=4
export GBT__SOURCE_MD5_LOCAL=md5
export GBT__THEME_REMOTE_CARS='Status, Os, Time, Hostname, Dir, Sign'
source $GBT__HOME/sources/gbts/cmd/local.sh


alias docker='gbt_docker'
alias screen='gbt_screen'
alias s='gbt_ssh'
alias su='gbt_su'
alias ssu="gbt_sudo su -"
alias sudo='gbt_sudo'
# alias vagrant='gbt_vagrant'
export GBT__SOURCE_MD5_LOCAL='md5'


# export GBT__HOME='/usr/share/gbt'


# export GBT__HOME="/usr/local/share/gbt"
# export GBT__THEME="$HOME/.gbt_theme_remote"
# export GBT__PROFILE="$HOME/.gbt_profile_remote"
# source "$GBT__HOME/sources/prompt_forwarding/local"
# alias ssh="gbt_ssh"
# alias gbt___sudo="gbt_sudo"

# alias s="gbt_ssh"
# alias ssu="gbt_sudo su -"

function S() {
    [ -z "$GBT__HOME$GBT__PROFILE" ] && gbt__err "'GBT__HOME' not defined" && return 1
    [ -z "$GBT__HOME$GBT__THEME" ] && gbt__err "'GBT__HOME' not defined" && return 1
    [ -z "$GBT__PROFILE" ] && GBT__PROFILE="$GBT__HOME/sources/ssh_prompt/remote"
    [ -z "$GBT__THEME" ] && GBT__THEME="$GBT__HOME/themes/ssh_prompt"

    local SSH_BIN=$(which ${GBT__WHICH_OPTS} ssh 2>/dev/null)
    [ $? -ne 0 ] && gbt__err "'ssh' not found" && return 1

    local SSH_OPTS="-o StrictHostKeyChecking=no -t"
    $SSH_BIN $SSH_OPTS $@ "
        cat /etc/motd 2>/dev/null;
        GBT__CONF=\"/tmp/.gbt.$RANDOM\" &&
        echo \"$(base64 $GBT__PROFILE | tr -d '\r\n')\" | base64 -d > \$GBT__CONF &&
        echo \"$(alias | awk '/gbt_/ {sub(/^(alias )|(gbt___)/,"", $0); print "alias "$0}')\" >> \$GBT__CONF &&
        echo \"PS1='$(source $GBT__THEME; gbt)'\" >> \$GBT__CONF &&
        sudo bash --rcfile \$GBT__CONF;
        rm -f \$GBT__CONF"
}
export PATH="/usr/local/opt/mysql-client/bin:$PATH"
alias kgp="kubectl get pods"
alias ksgp="kubectl -n kube-system get pods"
