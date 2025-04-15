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

install() {
    if ($1 == true); then
        echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Install nvim"
    else
        echo -e "${WARNGING_COLOR}${TRIANGEL}${RESET} Update nvim"
    fi
    curl -LO https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
    sudo rm /usr/bin/nvim
    sudo ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/bin/nvim
    rm nvim-linux-x86_64.tar.gz
}

case $1 in
    -c|--config)
        config
        ;;
    -u|--update)
        install false
        ;;
    *)               # Default case: No more options, so break out of the loop.
        break
esac

if ! (nvim -v > /dev/null) ; then
    install true
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

