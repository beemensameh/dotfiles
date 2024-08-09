#!/bin/bash

DIR=$(dirname "$0")
COLORS_FILE="${DIR}/_colors.sh"
SYMBOLS_FILE="${DIR}/_symbols.sh"

source $COLORS_FILE
source $SYMBOLS_FILE

if ! (find $HOME/.toprc | grep . > /dev/null); then
    echo -e "${WARNGING_COLOR}${CHECK_MARK}${RESET} Add .toprc"
    ln -s $PWD/$DIR/../home/.toprc $HOME/.toprc
fi
echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} .toprc has been added"

if ! (find $HOME/.gitconfig | grep . > /dev/null); then
    echo -e "${WARNGING_COLOR}${CHECK_MARK}${RESET} Add .gitconfig"
    ln -s $PWD/$DIR/../home/.gitconfig $HOME/.gitconfig
fi
echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} .gitconfig has been added"
