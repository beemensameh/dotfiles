#!/bin/bash

# Enhanced Neovim Installation Script
# Supports install, config, update, and uninstall operations
# Usage: ./install_nvim.sh [OPTIONS]
# Options:
#   -c, --config     Configure nvim (link config files)
#   -u, --update     Update nvim to latest version
#   -r, --remove     Remove nvim installation
#   -f, --force      Force reinstallation
#   -h, --help       Show this help message
#   -v, --verbose    Enable verbose output

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly NVIM_INSTALL_DIR="/opt/nvim-linux-x86_64"
readonly NVIM_BINARY="/usr/bin/nvim"
readonly NVIM_CONFIG_SOURCE="${SCRIPT_DIR}/../home/.config/nvim"
readonly NVIM_CONFIG_TARGET="${HOME}/.config/nvim"
readonly LOG_FILE="${HOME}/.nvim_install.log"

# Global variables
VERBOSE=false
FORCE=false

WARNING_COLOR="${WARNING_COLOR:-\033[1;33m}"
SUCCESS_COLOR="${SUCCESS_COLOR:-\033[1;32m}"
ERROR_COLOR="${ERROR_COLOR:-\033[1;31m}"
INFO_COLOR="${INFO_COLOR:-\033[1;34m}"
RESET="${RESET:-\033[0m}"
TRIANGLE="${TRIANGLE:-▲}"
CHECK_MARK="${CHECK_MARK:-✓}"
CROSS_MARK="${CROSS_MARK:-✗}"
INFO_MARK="${INFO_MARK:-ℹ}"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    case "$level" in
        "INFO")
            echo -e "${INFO_COLOR}${INFO_MARK}${RESET} $message"
            ;;
        "SUCCESS")
            echo -e "${SUCCESS_COLOR}${CHECK_MARK}${RESET} $message"
            ;;
        "WARNING")
            echo -e "${WARNING_COLOR}${TRIANGLE}${RESET} $message"
            ;;
        "ERROR")
            echo -e "${ERROR_COLOR}${CROSS_MARK}${RESET} $message" >&2
            ;;
    esac

    # Log to file if verbose mode is enabled
    if [[ "$VERBOSE" == true ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error_exit "This script should not be run as root. Use sudo for individual commands when needed."
    fi
}

# Check system requirements
check_requirements() {
    log "INFO" "Checking system requirements..."

    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        error_exit "curl is required but not installed. Please install curl first."
    fi

    # Check if tar is available
    if ! command -v tar &> /dev/null; then
        error_exit "tar is required but not installed."
    fi

    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log "WARNING" "Script may prompt for sudo password during installation"
    fi

    log "SUCCESS" "System requirements check passed"
}

# Get latest Neovim version
get_latest_version() {
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
    echo "${latest_version:-stable}"
}

# Get installed Neovim version
get_installed_version() {
    if command -v nvim &> /dev/null; then
        nvim --version | head -n1 | cut -d' ' -f2
    else
        echo "not_installed"
    fi
}

# Check if Neovim is installed
is_nvim_installed() {
    command -v nvim &> /dev/null
}

# Install/Update Neovim
install_nvim() {
    local is_update="$1"
    local action="Install"
    [[ "$is_update" == true ]] && action="Update"

    log "INFO" "${action}ing Neovim..."

    # Get version info
    local latest_version current_version
    latest_version=$(get_latest_version)
    current_version=$(get_installed_version)

    # Check if update is needed
    if [[ "$is_update" == true && "$current_version" != "not_installed" ]]; then
        log "INFO" "Current version: $current_version"
        log "INFO" "Latest version: $latest_version"

        if [[ "$current_version" == "$latest_version" && "$FORCE" != true ]]; then
            log "SUCCESS" "Neovim is already up to date"
            return 0
        fi
    fi

    # Create temporary directory
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # Download Neovim
    log "INFO" "Downloading Neovim..."
    if ! curl -fsSL "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz" -o nvim-linux-x86_64.tar.gz; then
        error_exit "Failed to download Neovim"
    fi

    # Verify download
    if [[ ! -f "nvim-linux-x86_64.tar.gz" || ! -s "nvim-linux-x86_64.tar.gz" ]]; then
        error_exit "Downloaded file is missing or empty"
    fi

    # Backup existing installation if it exists
    if [[ -d "$NVIM_INSTALL_DIR" ]]; then
        log "INFO" "Backing up existing installation..."
        sudo cp -r "$NVIM_INSTALL_DIR" "${NVIM_INSTALL_DIR}.backup.$(date +%s)" || true
    fi

    # Remove old installation
    log "INFO" "Removing old installation..."
    sudo rm -rf "$NVIM_INSTALL_DIR"
    [[ -L "$NVIM_BINARY" ]] && sudo rm -f "$NVIM_BINARY"

    # Extract new version
    log "INFO" "Extracting Neovim..."
    if ! sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz; then
        error_exit "Failed to extract Neovim"
    fi

    # Create symlink
    log "INFO" "Creating symlink..."
    if ! sudo ln -sf "${NVIM_INSTALL_DIR}/bin/nvim" "$NVIM_BINARY"; then
        error_exit "Failed to create symlink"
    fi

    # Cleanup
    cd - > /dev/null
    rm -rf "$temp_dir"

    # Verify installation
    if is_nvim_installed; then
        local new_version
        new_version=$(get_installed_version)
        log "SUCCESS" "Neovim ${action,,}ed successfully (version: $new_version)"
    else
        error_exit "Installation verification failed"
    fi
}

# Configure Neovim
configure_nvim() {
    log "INFO" "Configuring Neovim..."

    # Check if source config exists
    if [[ ! -d "$NVIM_CONFIG_SOURCE" ]]; then
        log "WARNING" "Source config directory not found: $NVIM_CONFIG_SOURCE"
        log "INFO" "Skipping configuration"
        return 0
    fi

    # Create .config directory if it doesn't exist
    mkdir -p "$(dirname "$NVIM_CONFIG_TARGET")"

    # Check if config already exists
    if [[ -e "$NVIM_CONFIG_TARGET" ]]; then
        if [[ "$FORCE" != true ]]; then
            log "WARNING" "Neovim config already exists at $NVIM_CONFIG_TARGET"
            log "INFO" "Use --force to overwrite existing configuration"
            return 0
        else
            log "INFO" "Removing existing configuration..."
            rm -rf "$NVIM_CONFIG_TARGET"
        fi
    fi

    # Create symlink
    log "INFO" "Creating configuration symlink..."
    if ln -sf "$NVIM_CONFIG_SOURCE" "$NVIM_CONFIG_TARGET"; then
        log "SUCCESS" "Neovim configured successfully"
    else
        error_exit "Failed to create configuration symlink"
    fi
}

# Install dependencies
install_dependencies() {
    log "INFO" "Installing dependencies..."

    # Install ripgrep for recursive search
    if ! command -v rg &> /dev/null; then
        log "INFO" "Installing ripgrep..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq
            sudo apt-get install -y ripgrep
        elif command -v yum &> /dev/null; then
            sudo yum install -y ripgrep
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y ripgrep
        else
            log "WARNING" "Could not install ripgrep: package manager not supported"
        fi
    fi

    if command -v rg &> /dev/null; then
        log "SUCCESS" "ripgrep is available"
    fi

    # Install xclip for clipboard support
    if ! command -v xclip &> /dev/null; then
        log "INFO" "Installing xclip..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y xclip
        elif command -v yum &> /dev/null; then
            sudo yum install -y xclip
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y xclip
        else
            log "WARNING" "Could not install xclip: package manager not supported"
        fi
    fi

    if command -v xclip &> /dev/null; then
        log "SUCCESS" "xclip is available"
    fi
}

# Remove Neovim
remove_nvim() {
    log "INFO" "Removing Neovim..."

    # Remove symlink
    if [[ -L "$NVIM_BINARY" ]]; then
        log "INFO" "Removing symlink..."
        sudo rm -f "$NVIM_BINARY"
    fi

    # Remove installation directory
    if [[ -d "$NVIM_INSTALL_DIR" ]]; then
        log "INFO" "Removing installation directory..."
        sudo rm -rf "$NVIM_INSTALL_DIR"
    fi

    # Ask about config removal
    if [[ -L "$NVIM_CONFIG_TARGET" ]]; then
        read -p "Remove Neovim configuration? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$NVIM_CONFIG_TARGET"
            log "SUCCESS" "Configuration removed"
        fi
    fi

    log "SUCCESS" "Neovim removed successfully"
}

# Show help
show_help() {
    cat << EOF
Enhanced Neovim Installation Script

Usage: $0 [OPTIONS]

Options:
    -c, --config     Configure nvim (link config files)
    -u, --update     Update nvim to latest version
    -r, --remove     Remove nvim installation
    -f, --force      Force reinstallation/reconfiguration
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

Examples:
    $0                 # Install nvim if not present
    $0 --config        # Configure nvim
    $0 --update        # Update nvim
    $0 --force         # Force reinstall nvim
    $0 --remove        # Remove nvim
    $0 --verbose       # Install with verbose output

Dependencies installed:
    - ripgrep (for recursive search)
    - xclip (for clipboard support)
EOF
}

# Main function
main() {
    local config_only=false
    local update_only=false
    local remove_only=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                config_only=true
                shift
                ;;
            -u|--update)
                update_only=true
                shift
                ;;
            -r|--remove)
                remove_only=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Check requirements
    check_root
    check_requirements

    # Handle specific operations
    if [[ "$remove_only" == true ]]; then
        remove_nvim
        exit 0
    fi

    if [[ "$config_only" == true ]]; then
        configure_nvim
        exit 0
    fi

    if [[ "$update_only" == true ]]; then
        if ! is_nvim_installed; then
            log "WARNING" "Neovim is not installed. Installing instead of updating."
            install_nvim false
        else
            install_nvim true
        fi
        exit 0
    fi

    # Default behavior: install if not present
    if ! is_nvim_installed || [[ "$FORCE" == true ]]; then
        install_nvim false
    else
        log "SUCCESS" "Neovim is already installed ($(get_installed_version))"
    fi

    # Install dependencies
    install_dependencies

    log "SUCCESS" "Setup completed successfully!"
}

# Run main function with all arguments
main "$@"
