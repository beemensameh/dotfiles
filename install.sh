#!/bin/bash
# Install all dotfiles (Entrypoint)

./scripts/setup_git_prompt.sh
./scripts/install_nvim.sh
./scripts/link_dotfiles.sh
