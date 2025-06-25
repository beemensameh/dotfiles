#!/bin/bash

# Enhanced Git Branch Prompt Configuration Script
# Adds git branch information and status to terminal prompt
# Usage: ./setup_git_prompt.sh [OPTIONS]
# Options:
#   -s, --simple     Use simple git branch display (default)
#   -d, --detailed   Use detailed git status display
#   -c, --custom     Use custom color scheme
#   -r, --remove     Remove git prompt configuration
#   -b, --backup     Backup .bashrc before modification
#   -f, --force      Force overwrite existing configuration
#   -h, --help       Show this help message
#   -v, --verbose    Enable verbose output

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASHRC_FILE="${HOME}/.bashrc"
readonly BACKUP_DIR="${HOME}/.config/prompt_backups"
readonly CONFIG_MARKER="# Enhanced Git Prompt Configuration"

# Global variables
VERBOSE=false
FORCE=false
BACKUP=false
PROMPT_STYLE="simple"

# colors and symbols
WARNING_COLOR="${WARNING_COLOR:-\033[1;33m}"
SUCCESS_COLOR="${SUCCESS_COLOR:-\033[1;32m}"
ERROR_COLOR="${ERROR_COLOR:-\033[1;31m}"
INFO_COLOR="${INFO_COLOR:-\033[1;34m}"
RESET="${RESET:-\033[0m}"
TRIANGLE="${TRIANGLE:-▲}"
CHECK_MARK="${CHECK_MARK:-✓}"
CROSS_MARK="${CROSS_MARK:-✗}"
INFO_MARK="${INFO_MARK:-ℹ}"

# Git status symbols
readonly GIT_CLEAN="✓"
readonly GIT_DIRTY="✗"
readonly GIT_STAGED="●"
readonly GIT_UNTRACKED="?"
readonly GIT_STASH="⚑"
readonly GIT_AHEAD="↑"
readonly GIT_BEHIND="↓"
readonly GIT_DIVERGED="↕"

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    
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
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        error_exit "Git is not installed. Please install git first."
    fi
}

# Backup .bashrc
backup_bashrc() {
    if [[ "$BACKUP" == true ]]; then
        log "INFO" "Creating backup of .bashrc..."
        mkdir -p "$BACKUP_DIR"
        local backup_file="${BACKUP_DIR}/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$BASHRC_FILE" "$backup_file"
        log "SUCCESS" "Backup created: $backup_file"
    fi
}

# Check if configuration already exists
config_exists() {
    grep -q "$CONFIG_MARKER" "$BASHRC_FILE" 2>/dev/null
}

# Remove existing configuration
remove_config() {
    if config_exists; then
        log "INFO" "Removing existing git prompt configuration..."
        
        # Create temporary file without the git prompt section
        local temp_file
        temp_file=$(mktemp)
        
        # Use awk to remove lines between markers
        awk "
        /$CONFIG_MARKER START/,/$CONFIG_MARKER END/ { next }
        { print }
        " "$BASHRC_FILE" > "$temp_file"
        
        # Replace original file
        mv "$temp_file" "$BASHRC_FILE"
        log "SUCCESS" "Git prompt configuration removed"
    else
        log "INFO" "No existing git prompt configuration found"
    fi
}

# Generate simple git branch function
generate_simple_function() {
    cat << 'EOF'
# Simple git branch parser
parse_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || return
    echo "($branch)"
}
EOF
}

# Generate detailed git status function
generate_detailed_function() {
    cat << 'EOF'
# Detailed git status parser
parse_git_status() {
    local branch status_output
    local clean_symbol="✓" dirty_symbol="✗" staged_symbol="●"
    local untracked_symbol="?" stash_symbol="⚑"
    local ahead_symbol="↑" behind_symbol="↓" diverged_symbol="↕"
    
    # Get current branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
        # Handle detached HEAD
        branch=$(git describe --exact-match HEAD 2>/dev/null) || {
            branch=$(git rev-parse --short HEAD 2>/dev/null) || return
            branch="detached:$branch"
        }
    }
    
    # Get git status
    status_output=$(git status --porcelain 2>/dev/null) || return
    
    local symbols=""
    
    # Check for staged changes
    if echo "$status_output" | grep -q '^[MADRC]'; then
        symbols="$symbols$staged_symbol"
    fi
    
    # Check for unstaged changes
    if echo "$status_output" | grep -q '^.[MD]'; then
        symbols="$symbols$dirty_symbol"
    fi
    
    # Check for untracked files
    if echo "$status_output" | grep -q '^??'; then
        symbols="$symbols$untracked_symbol"
    fi
    
    # Check for clean status
    if [[ -z "$status_output" ]]; then
        symbols="$clean_symbol"
    fi
    
    # Check for stashes
    if [[ $(git stash list 2>/dev/null | wc -l) -gt 0 ]]; then
        symbols="$symbols$stash_symbol"
    fi
    
    # Check remote tracking status
    local remote_info
    remote_info=$(git status --porcelain=v1 --branch 2>/dev/null | head -n1)
    if [[ "$remote_info" =~ \[ahead\ ([0-9]+)\] ]]; then
        symbols="$symbols$ahead_symbol${BASH_REMATCH[1]}"
    elif [[ "$remote_info" =~ \[behind\ ([0-9]+)\] ]]; then
        symbols="$symbols$behind_symbol${BASH_REMATCH[1]}"
    elif [[ "$remote_info" =~ \[ahead\ ([0-9]+),\ behind\ ([0-9]+)\] ]]; then
        symbols="$symbols$diverged_symbol${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
    
    echo "($branch$symbols)"
}
EOF
}

# Generate prompt configuration based on style
generate_prompt_config() {
    local git_function prompt_def
    
    case "$PROMPT_STYLE" in
        "simple")
            git_function=$(generate_simple_function)
            prompt_def='export PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \[\e[91m\]\$(parse_git_branch)\[\033[00m\]\$ "'
            ;;
        "detailed")
            git_function=$(generate_detailed_function)
            prompt_def='export PS1="${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w \[\e[93m\]\$(parse_git_status)\[\033[00m\]\$ "'
            ;;
        "custom")
            git_function=$(generate_detailed_function)
            prompt_def='export PS1="\[\033[1;36m\]\u\[\033[1;37m\]@\[\033[1;33m\]\h\[\033[00m\]:\[\033[1;35m\]\w \[\033[1;32m\]\$(parse_git_status)\[\033[00m\]\$ "'
            ;;
    esac
    
    cat << EOF

$CONFIG_MARKER START
# Generated by enhanced git prompt script on $(date)
# Style: $PROMPT_STYLE

$git_function

# Set the enhanced prompt
$prompt_def

$CONFIG_MARKER END
EOF
}

# Install git prompt configuration
install_config() {
    log "INFO" "Installing git prompt configuration (style: $PROMPT_STYLE)..."
    
    # Check if configuration already exists
    if config_exists && [[ "$FORCE" != true ]]; then
        log "WARNING" "Git prompt configuration already exists"
        log "INFO" "Use --force to overwrite or --remove to remove existing configuration"
        return 0
    fi
    
    # Backup if requested
    backup_bashrc
    
    # Remove existing configuration if force is enabled
    if [[ "$FORCE" == true ]]; then
        remove_config
    fi
    
    # Add new configuration
    log "INFO" "Adding git prompt configuration to .bashrc..."
    generate_prompt_config >> "$BASHRC_FILE"
    
    log "SUCCESS" "Git prompt configuration installed successfully"
    log "INFO" "Run 'source ~/.bashrc' or restart your terminal to apply changes"
    
    # Show preview
    if [[ "$VERBOSE" == true ]]; then
        log "INFO" "Configuration preview:"
        echo "----------------------------------------"
        generate_prompt_config | sed 's/^/  /'
        echo "----------------------------------------"
    fi
}

# Show current git prompt status
show_status() {
    log "INFO" "Git prompt status:"
    
    if config_exists; then
        log "SUCCESS" "Git prompt is configured"
        
        # Try to determine the style
        if grep -q "parse_git_status" "$BASHRC_FILE"; then
            if grep -q "1;36m" "$BASHRC_FILE"; then
                echo "  Style: custom"
            else
                echo "  Style: detailed"
            fi
        else
            echo "  Style: simple"
        fi
    else
        log "INFO" "Git prompt is not configured"
    fi
    
    # Check git availability
    if command -v git &> /dev/null; then
        log "SUCCESS" "Git is available ($(git --version | cut -d' ' -f3))"
    else
        log "WARNING" "Git is not installed"
    fi
}

# Show help
show_help() {
    cat << EOF
Enhanced Git Branch Prompt Configuration Script

This script configures your bash prompt to display git branch information
and optionally git status indicators.

Usage: $0 [OPTIONS]

Options:
    -s, --simple     Use simple git branch display (default)
    -d, --detailed   Use detailed git status display with symbols
    -c, --custom     Use custom color scheme with detailed status
    -r, --remove     Remove git prompt configuration
    -b, --backup     Backup .bashrc before modification
    -f, --force      Force overwrite existing configuration
    --status         Show current git prompt status
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

Prompt Styles:
    simple      Shows only branch name: (main)
    detailed    Shows branch + status: (main✓) or (main✗●?)
    custom      Same as detailed but with custom colors

Status Symbols (detailed/custom):
    ✓  Clean working directory
    ✗  Modified files
    ●  Staged files
    ?  Untracked files
    ⚑  Stashed changes
    ↑  Commits ahead of remote
    ↓  Commits behind remote
    ↕  Diverged from remote

Examples:
    $0                    # Install simple git prompt
    $0 --detailed         # Install detailed git prompt
    $0 --custom --backup  # Install custom prompt with backup
    $0 --remove           # Remove git prompt configuration
    $0 --status           # Show current status

Note: Run 'source ~/.bashrc' after installation to apply changes.
EOF
}

# Main function
main() {
    local remove_only=false
    local status_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--simple)
                PROMPT_STYLE="simple"
                shift
                ;;
            -d|--detailed)
                PROMPT_STYLE="detailed"
                shift
                ;;
            -c|--custom)
                PROMPT_STYLE="custom"
                shift
                ;;
            -r|--remove)
                remove_only=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --status)
                status_only=true
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
    
    # Check if .bashrc exists
    if [[ ! -f "$BASHRC_FILE" ]]; then
        log "WARNING" ".bashrc file not found, creating one..."
        touch "$BASHRC_FILE"
    fi
    
    # Handle specific operations
    if [[ "$status_only" == true ]]; then
        show_status
        exit 0
    fi
    
    if [[ "$remove_only" == true ]]; then
        backup_bashrc
        remove_config
        exit 0
    fi
    
    # Check git availability for installation
    check_git
    
    # Install configuration
    install_config
    
    log "SUCCESS" "Git prompt setup completed!"
    
    if [[ "$VERBOSE" == true ]]; then
        echo ""
        show_status
    fi
}

# Run main function with all arguments
main "$@"
