#!/bin/bash
# Install nvim editor
# If you pass --config for this script, it will move the nvim dir config to the home .config dir

DIR=$(dirname "$0")
COLORS_FILE="${DIR}/_colors.sh"
SYMBOLS_FILE="${DIR}/_symbols.sh"

source $COLORS_FILE
source $SYMBOLS_FILE

config() {
    if ! (find $HOME/.config -maxdepth 1 -name nvim | grep . > /dev/null); then
        echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Add nvim configution"
        ln -s $PWD/$DIR/../home/.config/nvim $HOME/.config/nvim
    fi
    echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} Nvim configured"
}

if ! (nvim -v > /dev/null) ; then
    echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Install nvim"
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim /opt/nvim-linux64
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    sudo rm /usr/bin/nvim
    sudo ln -s /opt/nvim-linux64/bin/nvim /usr/bin/nvim
    rm nvim-linux64.tar.gz
fi
echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} Nvim installed"

# For enable recursive search in dirs
if !(rg -V > /dev/null); then
    echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Install ripgrep"
    sudo apt-get install ripgrep -y
fi
echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} ripgrep installed"

# For enable clipboard
if !(xclip -version > /dev/null); then
    echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Install xclip"
    sudo apt-get install xclip -y
fi
echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} xclip installed"

while :; do
    case $1 in
        -c|--config)
            config
            exit
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done
