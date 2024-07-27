#!/bin/sh

config() {
    echo '\033[34;1m▶\033[0m Add nvim configution'
    ln -s $PWD/../home/.config/nvim ~/.config/nvim
}

echo '\033[34;1m▶\033[0m Check nvim'
if ! (nvim -v > /dev/null) ; then
    echo '\033[33;1m▶\033[0m Install nvim'
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
    sudo rm -rf /opt/nvim /opt/nvim-linux64
    sudo tar -C /opt -xzf nvim-linux64.tar.gz
    sudo rm /usr/bin/nvim
    sudo ln -s /opt/nvim-linux64/bin/nvim /usr/bin/nvim
    rm nvim-linux64.tar.gz
fi
echo '\033[32;1m▶\033[0m Nvim installed'

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
