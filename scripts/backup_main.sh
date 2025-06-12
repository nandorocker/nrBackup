#!/bin/bash

# nrBackup - Main Backup Script
# This script orchestrates the entire backup process

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SUPPORT_DIR="$HOME/Library/Application Support/nrBackup"
CONFIG_FILE="$APP_SUPPORT_DIR/config.json"
LOG_DIR="$HOME/Library/Logs/nrBackup"
HELPERS_DIR="$SCRIPT_DIR/helpers"

# Source helper scripts
source "$HELPERS_DIR/config_parser.sh"
source "$HELPERS_DIR/logger.sh"
source "$HELPERS_DIR/notification_sender.sh"

# Global variables
BACKUP_START_TIME=""
BACKUP_END_TIME=""
BACKUP_SUCCESS=false
RSYNC_EXIT_CODE=0
COMPUTER_NAME=""
DESTINATION_PATH=""

# Initialize backup process
initialize_backup() {
    BACKUP_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    COMPUTER_NAME=$(hostname -s)
    
    # Create log directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    log_info "=== nrBackup Started ==="
    log_info "Start time: $BACKUP_START_TIME"
    log_info "Computer: $COMPUTER_NAME"
}

# Validate paths and prerequisites
validate_environment() {
    log_info "Validating environment..."
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        send_failure_notification "Configuration file not found"
        exit 1
    fi
    
    # Parse configuration
    if ! parse_config "$CONFIG_FILE"; then
        log_error "Failed to parse configuration file"
        send_failure_notification "Invalid configuration"
        exit 1
    fi
    
    # Check if destination drive is mounted
    if [[ ! -d "$DESTINATION_DRIVE" ]]; then
        log_error "Destination drive not found or not mounted: $DESTINATION_DRIVE"
        send_failure_notification "Backup drive not connected"
        exit 1
    fi
    
    # Create destination backup path
    DESTINATION_PATH="$DESTINATION_DRIVE/Backups/$COMPUTER_NAME"
    mkdir -p "$DESTINATION_PATH"
    
    log_info "Destination path: $DESTINATION_PATH"
    
    # Validate source paths
    for source in "${SOURCE_PATHS[@]}"; do
        if [[ ! -d "$source" ]]; then
            log_warning "Source path does not exist: $source"
        else
            log_info "Source path validated: $source"
        fi
    done
}

# Build rsync command with all options
build_rsync_command() {
    local rsync_cmd="nice -n 10 rsync"
    
    # Basic rsync options
    rsync_cmd+=" -aHX"  # Archive mode, hard links, extended attributes
    rsync_cmd+=" --delete"  # Delete files in destination that don't exist in source
    rsync_cmd+=" --delete-excluded"  # Delete excluded files from destination
    
    # Progress and stats (only when running interactively)
    if [[ -t 1 ]]; then
        rsync_cmd+=" --progress --stats"
    else
        rsync_cmd+=" --stats"
    fi
    
    # Add exclusions
    for exclude in "${EXCLUDE_PATHS[@]}"; do
        rsync_cmd+=" --exclude='$exclude'"
    done
    
    # Add sources and destination
    for source in "${SOURCE_PATHS[@]}"; do
        if [[ -d "$source" ]]; then
            # Ensure source ends with / for proper rsync behavior
            if [[ "$source" != */ ]]; then
                source="$source/"
            fi
            rsync_cmd+=" '$source'"
        fi
    done
    
    rsync_cmd+=" '$DESTINATION_PATH/'"
    
    echo "$rsync_cmd"
}

# Execute the backup
perform_backup() {
    log_info "Starting backup process..."
    
    local rsync_command
    rsync_command=$(build_rsync_command)
    
    log_info "Executing rsync command:"
    log_info "$rsync_command"
    
    # Create temporary file for rsync output
    local rsync_output_file
    rsync_output_file=$(mktemp)
    
    # Execute rsync and capture output
    if eval "$rsync_command" > "$rsync_output_file" 2>&1; then
        RSYNC_EXIT_CODE=0
        BACKUP_SUCCESS=true
        log_info "Backup completed successfully"
    else
        RSYNC_EXIT_CODE=$?
        BACKUP_SUCCESS=false
        log_error "Backup failed with exit code: $RSYNC_EXIT_CODE"
    fi
    
    # Log rsync output based on logging level
    if [[ "$DETAILED_LOGGING" == "true" ]]; then
        log_info "=== rsync Output ==="
        cat "$rsync_output_file" | while IFS= read -r line; do
            log_info "$line"
        done
        log_info "=== End rsync Output ==="
    else
        # Extract just the summary statistics for basic logging
        if grep -q "Number of files:" "$rsync_output_file"; then
            log_info "=== Backup Summary ==="
            grep -E "(Number of files|Number of created files|Number of deleted files|Total file size|Total transferred file size|Literal data|Matched data|File list size|File list generation time|File list transfer time|Total bytes sent|Total bytes received)" "$rsync_output_file" | while IFS= read -r line; do
                log_info "$line"
            done
            log_info "=== End Summary ==="
        fi
    fi
    
    # Clean up temporary file
    rm -f "$rsync_output_file"
}

# Finalize backup and send notifications
finalize_backup() {
    BACKUP_END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
    local duration
    duration=$(( $(date -j -f '%Y-%m-%d %H:%M:%S' "$BACKUP_END_TIME" '+%s') - $(date -j -f '%Y-%m-%d %H:%M:%S' "$BACKUP_START_TIME" '+%s') ))
    
    log_info "=== nrBackup Finished ==="
    log_info "End time: $BACKUP_END_TIME"
    log_info "Duration: ${duration} seconds"
    log_info "Success: $BACKUP_SUCCESS"
    
    if [[ "$BACKUP_SUCCESS" == "true" ]]; then
        send_success_notification "$duration" "$DESTINATION_PATH"
    else
        send_failure_notification "rsync failed with exit code $RSYNC_EXIT_CODE"
    fi
}

# Main execution
main() {
    # Set up error handling
    trap 'log_error "Script interrupted"; send_failure_notification "Backup interrupted"; exit 1' INT TERM
    
    initialize_backup
    validate_environment
    perform_backup
    finalize_backup
    
    # Exit with appropriate code
    if [[ "$BACKUP_SUCCESS" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"
