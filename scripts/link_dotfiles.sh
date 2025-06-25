#!/bin/bash

# Enhanced Dotfiles Linking Script
# Creates symbolic links for dotfiles from a source directory to home directory
# Usage: ./link_dotfiles.sh [OPTIONS] [FILES...]
# Options:
#   -s, --source DIR     Source directory containing dotfiles (default: ../home)
#   -t, --target DIR     Target directory for links (default: $HOME)
#   -f, --force          Force overwrite existing files/links
#   -b, --backup         Backup existing files before linking
#   -r, --remove         Remove existing symbolic links
#   -l, --list           List available dotfiles
#   -c, --check          Check status of dotfiles
#   -d, --dry-run        Show what would be done without doing it
#   -v, --verbose        Enable verbose output
#   -h, --help           Show this help message

set -euo pipefail

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_SOURCE_DIR="${SCRIPT_DIR}/../home"
readonly DEFAULT_TARGET_DIR="${HOME}"
readonly BACKUP_DIR="${HOME}/.dotfiles_backup"

# Global variables
VERBOSE=false
FORCE=false
BACKUP=false
DRY_RUN=false
SOURCE_DIR=""
TARGET_DIR=""

# Default dotfiles to manage
declare -a DEFAULT_DOTFILES=(
    ".toprc"
    ".gitconfig"
)

# colors and symbols - Fixed color variable definitions
readonly WARNING_COLOR='\033[1;33m'
readonly SUCCESS_COLOR='\033[1;32m'
readonly ERROR_COLOR='\033[1;31m'
readonly INFO_COLOR='\033[1;34m'
readonly RESET='\033[0m'
readonly TRIANGLE='▲'
readonly CHECK_MARK='✓'
readonly CROSS_MARK='✗'
readonly INFO_MARK='ℹ'
readonly LINK_SYMBOL='→'

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
        "LINK")
            echo -e "${INFO_COLOR}${LINK_SYMBOL}${RESET} $message"
            ;;
    esac
}

# Error handling
error_exit() {
    log "ERROR" "$1"
    exit "${2:-1}"
}

# Initialize directories
init_directories() {
    SOURCE_DIR="${SOURCE_DIR:-$DEFAULT_SOURCE_DIR}"
    TARGET_DIR="${TARGET_DIR:-$DEFAULT_TARGET_DIR}"
    
    # Convert to absolute paths
    SOURCE_DIR="$(cd "$SOURCE_DIR" 2>/dev/null && pwd)" || error_exit "Source directory does not exist: $SOURCE_DIR"
    TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || error_exit "Target directory does not exist: $TARGET_DIR"
    
    if [[ "$VERBOSE" == true ]]; then
        log "INFO" "Source directory: $SOURCE_DIR"
        log "INFO" "Target directory: $TARGET_DIR"
    fi
    
    # Create backup directory if needed
    if [[ "$BACKUP" == true ]]; then
        mkdir -p "$BACKUP_DIR"
        if [[ "$VERBOSE" == true ]]; then
            log "INFO" "Backup directory: $BACKUP_DIR"
        fi
    fi
}

# Get list of available dotfiles
get_available_dotfiles() {
    local dotfiles=()
    
    # Check each default dotfile
    for file in "${DEFAULT_DOTFILES[@]}"; do
        if [[ -f "$SOURCE_DIR/$file" ]]; then
            dotfiles+=("$file")
        fi
    done
    
    # Add any other dotfiles found in source directory
    while IFS= read -r -d '' file; do
        local basename_file
        basename_file="$(basename "$file")"
        
        # Skip if already in our list
        if [[ ! " ${dotfiles[*]} " =~ " ${basename_file} " ]]; then
            # Only include hidden files (dotfiles)
            if [[ "$basename_file" == .* ]]; then
                dotfiles+=("$basename_file")
            fi
        fi
    done < <(find "$SOURCE_DIR" -maxdepth 1 -type f -name ".*" -print0 2>/dev/null)
    
    printf '%s\n' "${dotfiles[@]}" | sort
}

# Check if a file exists and what type it is
check_file_status() {
    local file="$1"
    local target_path="$TARGET_DIR/$file"
    
    if [[ ! -e "$target_path" ]]; then
        echo "missing"
    elif [[ -L "$target_path" ]]; then
        local link_target
        link_target="$(readlink "$target_path")"
        if [[ "$link_target" == "$SOURCE_DIR/$file" ]]; then
            echo "linked"
        else
            echo "wrong_link"
        fi
    elif [[ -f "$target_path" ]]; then
        echo "file"
    elif [[ -d "$target_path" ]]; then
        echo "directory"
    else
        echo "unknown"
    fi
}

# Backup existing file
backup_file() {
    local file="$1"
    local target_path="$TARGET_DIR/$file"
    
    if [[ ! -e "$target_path" ]]; then
        return 0
    fi
    
    local backup_path="${BACKUP_DIR}/${file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "[DRY RUN] Would backup $file to $backup_path"
        return 0
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        log "INFO" "Backing up $file to $backup_path"
    fi
    
    cp -r "$target_path" "$backup_path" || error_exit "Failed to backup $file"
}

# Create symbolic link
create_link() {
    local file="$1"
    local source_path="$SOURCE_DIR/$file"
    local target_path="$TARGET_DIR/$file"
    local status
    
    # Check if source file exists
    if [[ ! -f "$source_path" ]]; then
        log "WARNING" "Source file not found: $source_path"
        return 1
    fi
    
    status="$(check_file_status "$file")"
    
    case "$status" in
        "linked")
            log "SUCCESS" "$file is already linked correctly"
            return 0
            ;;
        "missing")
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "[DRY RUN] Would create link: $file"
                return 0
            fi
            
            log "LINK" "Creating link for $file"
            ln -s "$source_path" "$target_path" || error_exit "Failed to create link for $file"
            log "SUCCESS" "$file linked successfully"
            ;;
        "file"|"directory"|"wrong_link")
            if [[ "$FORCE" != true ]]; then
                log "WARNING" "$file already exists (use --force to overwrite)"
                return 1
            fi
            
            if [[ "$BACKUP" == true ]]; then
                backup_file "$file"
            fi
            
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "[DRY RUN] Would overwrite $file"
                return 0
            fi
            
            log "WARNING" "Overwriting existing $file"
            rm -rf "$target_path"
            ln -s "$source_path" "$target_path" || error_exit "Failed to create link for $file"
            log "SUCCESS" "$file linked successfully"
            ;;
        *)
            log "ERROR" "Unknown status for $file: $status"
            return 1
            ;;
    esac
}

# Remove symbolic link
remove_link() {
    local file="$1"
    local target_path="$TARGET_DIR/$file"
    local status
    
    status="$(check_file_status "$file")"
    
    case "$status" in
        "linked")
            if [[ "$DRY_RUN" == true ]]; then
                log "INFO" "[DRY RUN] Would remove link: $file"
                return 0
            fi
            
            log "INFO" "Removing link for $file"
            rm "$target_path" || error_exit "Failed to remove link for $file"
            log "SUCCESS" "$file link removed"
            ;;
        "missing")
            log "INFO" "$file is not linked"
            ;;
        "wrong_link")
            if [[ "$FORCE" == true ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    log "INFO" "[DRY RUN] Would remove wrong link: $file"
                    return 0
                fi
                
                log "WARNING" "Removing incorrect link for $file"
                rm "$target_path" || error_exit "Failed to remove wrong link for $file"
                log "SUCCESS" "$file wrong link removed"
            else
                log "WARNING" "$file has wrong link target (use --force to remove)"
            fi
            ;;
        *)
            log "WARNING" "$file is not a symbolic link"
            ;;
    esac
}

# List available dotfiles
list_dotfiles() {
    local dotfiles
    mapfile -t dotfiles < <(get_available_dotfiles)
    
    if [[ ${#dotfiles[@]} -eq 0 ]]; then
        log "INFO" "No dotfiles found in $SOURCE_DIR"
        return 0
    fi
    
    log "INFO" "Available dotfiles in $SOURCE_DIR:"
    for file in "${dotfiles[@]}"; do
        local status
        status="$(check_file_status "$file")"
        
        case "$status" in
            "linked")
                printf "  %b%s%b %s (linked)\n" "$SUCCESS_COLOR" "$CHECK_MARK" "$RESET" "$file"
                ;;
            "missing")
                printf "  %b%s%b %s (not linked)\n" "$WARNING_COLOR" "$TRIANGLE" "$RESET" "$file"
                ;;
            "wrong_link")
                printf "  %b%s%b %s (wrong link)\n" "$ERROR_COLOR" "$CROSS_MARK" "$RESET" "$file"
                ;;
            "file"|"directory")
                printf "  %b%s%b %s (exists, not linked)\n" "$WARNING_COLOR" "$TRIANGLE" "$RESET" "$file"
                ;;
            *)
                printf "  %b%s%b %s (unknown status)\n" "$ERROR_COLOR" "$CROSS_MARK" "$RESET" "$file"
                ;;
        esac
    done
}

# Check status of dotfiles - Fixed arithmetic operations
check_status() {
    local dotfiles
    mapfile -t dotfiles < <(get_available_dotfiles)
    
    if [[ ${#dotfiles[@]} -eq 0 ]]; then
        log "INFO" "No dotfiles found in $SOURCE_DIR"
        return 0
    fi
    
    # Initialize counters to avoid arithmetic errors with set -e
    local linked=0 missing=0 wrong=0 existing=0
    
    log "INFO" "Checking dotfiles status..."
    
    for file in "${dotfiles[@]}"; do
        local status
        status="$(check_file_status "$file")"
        
        case "$status" in
            "linked")
                linked=$((linked + 1))
                if [[ "$VERBOSE" == true ]]; then
                    log "SUCCESS" "$file is linked correctly"
                fi
                ;;
            "missing")
                missing=$((missing + 1))
                if [[ "$VERBOSE" == true ]]; then
                    log "WARNING" "$file is not linked"
                fi
                ;;
            "wrong_link")
                wrong=$((wrong + 1))
                if [[ "$VERBOSE" == true ]]; then
                    log "ERROR" "$file has wrong link target"
                fi
                ;;
            "file"|"directory")
                existing=$((existing + 1))
                if [[ "$VERBOSE" == true ]]; then
                    log "WARNING" "$file exists but is not linked"
                fi
                ;;
        esac
    done
    
    echo ""
    log "INFO" "Status summary:"
    echo "  Correctly linked: $linked"
    echo "  Not linked: $missing"
    echo "  Wrong links: $wrong"
    echo "  Existing files: $existing"
    echo "  Total dotfiles: ${#dotfiles[@]}"
}

# Show help
show_help() {
    cat << EOF
Enhanced Dotfiles Linking Script

This script creates symbolic links for dotfiles from a source directory
to your home directory (or specified target directory).

Usage: $0 [OPTIONS] [FILES...]

Options:
    -s, --source DIR     Source directory containing dotfiles (default: ../home)
    -t, --target DIR     Target directory for links (default: \$HOME)
    -f, --force          Force overwrite existing files/links
    -b, --backup         Backup existing files before linking
    -r, --remove         Remove existing symbolic links
    -l, --list           List available dotfiles and their status
    -c, --check          Check status of dotfiles
    -d, --dry-run        Show what would be done without doing it
    -v, --verbose        Enable verbose output
    -h, --help           Show this help message

Arguments:
    FILES...             Specific dotfiles to process (default: all available)

Default dotfiles managed:
    .toprc, .gitconfig, .vimrc, .tmux.conf, .bash_aliases,
    .inputrc, .screenrc, .dircolors, .profile, .bashrc,
    .zshrc, .gitignore_global

Examples:
    $0                           # Link all available dotfiles
    $0 .toprc .gitconfig         # Link only specific files
    $0 --list                    # List available dotfiles
    $0 --check                   # Check current status
    $0 --force --backup          # Force link with backup
    $0 --remove .toprc           # Remove specific link
    $0 --dry-run --verbose       # Preview what would be done
    $0 --source /path/to/dots    # Use custom source directory

Status indicators:
    $(printf "%b%s%b" "$SUCCESS_COLOR" "$CHECK_MARK" "$RESET") Correctly linked
    $(printf "%b%s%b" "$WARNING_COLOR" "$TRIANGLE" "$RESET") Not linked or existing file
    $(printf "%b%s%b" "$ERROR_COLOR" "$CROSS_MARK" "$RESET") Wrong link or error
EOF
}

# Main function
main() {
    local operation="link"
    local specific_files=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_DIR="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            -r|--remove)
                operation="remove"
                shift
                ;;
            -l|--list)
                operation="list"
                shift
                ;;
            -c|--check)
                operation="check"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
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
            -*)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                # Remaining arguments are specific files
                specific_files+=("$1")
                shift
                ;;
        esac
    done
    
    # Initialize directories
    init_directories
    
    # Handle specific operations
    case "$operation" in
        "list")
            list_dotfiles
            exit 0
            ;;
        "check")
            check_status
            exit 0
            ;;
    esac
    
    # Determine which files to process
    local files_to_process=()
    if [[ ${#specific_files[@]} -gt 0 ]]; then
        files_to_process=("${specific_files[@]}")
    else
        mapfile -t files_to_process < <(get_available_dotfiles)
    fi
    
    if [[ ${#files_to_process[@]} -eq 0 ]]; then
        log "WARNING" "No dotfiles found to process"
        exit 0
    fi
    
    # Process files
    local success_count=0
    local total_count=${#files_to_process[@]}
    
    if [[ "$DRY_RUN" == true ]]; then
        log "INFO" "DRY RUN MODE - No changes will be made"
    fi
    
    log "INFO" "Processing $total_count dotfile(s)..."
    
    for file in "${files_to_process[@]}"; do
        case "$operation" in
            "link")
                if create_link "$file"; then
                    success_count=$((success_count + 1))
                fi
                ;;
            "remove")
                if remove_link "$file"; then
                    success_count=$((success_count + 1))
                fi
                ;;
        esac
    done
    
    # Summary
    echo ""
    if [[ "$operation" == "link" ]]; then
        log "SUCCESS" "Linking completed: $success_count/$total_count files processed"
    else
        log "SUCCESS" "Removal completed: $success_count/$total_count files processed"
    fi
    
    if [[ "$VERBOSE" == true && "$operation" == "link" ]]; then
        echo ""
        check_status
    fi
}

# Run main function with all arguments
main "$@"
