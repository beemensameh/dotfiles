#!/bin/bash
# this file add the additional lines at the end of .bashrc file

DIR=$(dirname "$0")
COLORS_FILE="${DIR}/_colors.sh"
SYMBOLS_FILE="${DIR}/_symbols.sh"

source $COLORS_FILE
source $SYMBOLS_FILE

if ! (grep "# Git branch name" $HOME/.bashrc > /dev/null); then
     echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Add git branch name to prompt"
     echo "
     # Git branch name
     parse_git_branch() {
          git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
     }
     export PS1=\"${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \[\e[91m\]\$(parse_git_branch)\[\033[00m\]\$ \"" >> $HOME/.bashrc
fi
echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} Git branch name has been added"
