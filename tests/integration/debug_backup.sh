#!/bin/bash

# nrBackup - Debug Version of Main Backup Script
# This script provides detailed debugging output for troubleshooting

set -euo pipefail

# Enable debug mode
set -x

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SUPPORT_DIR="$HOME/Library/Application Support/nrBackup"
CONFIG_FILE="$APP_SUPPORT_DIR/config.json"
LOG_DIR="$HOME/Library/Logs/nrBackup"
HELPERS_DIR="$SCRIPT_DIR/scripts/helpers"

# Debug output function
debug_info() {
    echo "DEBUG: $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $1"
}

debug_info "=== nrBackup Debug Mode Started ==="
debug_info "Script directory: $SCRIPT_DIR"
debug_info "Config file: $CONFIG_FILE"
debug_info "Log directory: $LOG_DIR"
debug_info "Helpers directory: $HELPERS_DIR"

# Check if files exist
debug_info "Checking file existence..."
for file in "$CONFIG_FILE" "$HELPERS_DIR/config_parser.sh" "$HELPERS_DIR/logger.sh" "$HELPERS_DIR/notification_sender.sh"; do
    if [[ -f "$file" ]]; then
        debug_info "✅ Found: $file"
    else
        debug_info "❌ Missing: $file"
    fi
done

# Source helper scripts with error handling
debug_info "Sourcing helper scripts..."
if [[ -f "$HELPERS_DIR/config_parser.sh" ]]; then
    source "$HELPERS_DIR/config_parser.sh"
    debug_info "✅ Sourced config_parser.sh"
else
    debug_info "❌ Cannot source config_parser.sh"
    exit 1
fi

if [[ -f "$HELPERS_DIR/logger.sh" ]]; then
    source "$HELPERS_DIR/logger.sh"
    debug_info "✅ Sourced logger.sh"
else
    debug_info "❌ Cannot source logger.sh"
    exit 1
fi

if [[ -f "$HELPERS_DIR/notification_sender.sh" ]]; then
    source "$HELPERS_DIR/notification_sender.sh"
    debug_info "✅ Sourced notification_sender.sh"
else
    debug_info "❌ Cannot source notification_sender.sh"
    exit 1
fi

# Test configuration parsing
debug_info "Testing configuration parsing..."
if [[ -f "$CONFIG_FILE" ]]; then
    debug_info "Config file exists, attempting to parse..."
    if parse_config "$CONFIG_FILE"; then
        debug_info "✅ Configuration parsed successfully"
        debug_info "Schedule type: $SCHEDULE_TYPE"
        debug_info "Destination drive: $DESTINATION_DRIVE"
        debug_info "Source paths: ${SOURCE_PATHS[*]}"
        debug_info "Number of exclude paths: ${#EXCLUDE_PATHS[@]}"
    else
        debug_info "❌ Configuration parsing failed"
        exit 1
    fi
else
    debug_info "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Check destination drive
debug_info "Checking destination drive..."
if [[ -d "$DESTINATION_DRIVE" ]]; then
    debug_info "✅ Destination drive mounted: $DESTINATION_DRIVE"
    debug_info "Destination drive contents:"
    ls -la "$DESTINATION_DRIVE" | head -10
else
    debug_info "❌ Destination drive not found: $DESTINATION_DRIVE"
    debug_info "Available volumes:"
    ls -la /Volumes/ 2>/dev/null || debug_info "Cannot list /Volumes/"
fi

# Check source paths
debug_info "Checking source paths..."
for source in "${SOURCE_PATHS[@]}"; do
    if [[ -d "$source" ]]; then
        debug_info "✅ Source path exists: $source"
        debug_info "Source path size: $(du -sh "$source" 2>/dev/null | cut -f1 || echo "unknown")"
    else
        debug_info "❌ Source path not found: $source"
    fi
done

# Test rsync command
debug_info "Testing rsync command..."
COMPUTER_NAME=$(hostname -s)
DESTINATION_PATH="$DESTINATION_DRIVE/Backups/$COMPUTER_NAME"

debug_info "Computer name: $COMPUTER_NAME"
debug_info "Destination path: $DESTINATION_PATH"

# Build rsync command
rsync_cmd="rsync -aH --delete --delete-excluded --stats"

# Add exclusions
for exclude in "${EXCLUDE_PATHS[@]}"; do
    rsync_cmd+=" --exclude='$exclude'"
done

# Add sources
for source in "${SOURCE_PATHS[@]}"; do
    if [[ -d "$source" ]]; then
        if [[ "$source" != */ ]]; then
            source="$source/"
        fi
        rsync_cmd+=" '$source'"
    fi
done

rsync_cmd+=" '$DESTINATION_PATH/'"

debug_info "Full rsync command: $rsync_cmd"

# Test rsync with dry-run first
debug_info "Testing rsync with dry-run..."
dry_run_cmd="${rsync_cmd} --dry-run"
debug_info "Dry-run command: $dry_run_cmd"

if eval "$dry_run_cmd" > /tmp/rsync_dryrun.log 2>&1; then
    debug_info "✅ Dry-run successful"
    debug_info "Dry-run output (first 20 lines):"
    head -20 /tmp/rsync_dryrun.log
else
    debug_info "❌ Dry-run failed"
    debug_info "Dry-run error output:"
    cat /tmp/rsync_dryrun.log
    exit 1
fi

# Ask user if they want to proceed with actual backup
echo ""
echo "DEBUG MODE: Dry-run completed successfully."
echo "Would you like to proceed with the actual backup? (y/N)"
read -r proceed

if [[ "$proceed" =~ ^[Yy] ]]; then
    debug_info "Proceeding with actual backup..."
    
    # Create destination directory if it doesn't exist
    mkdir -p "$DESTINATION_PATH"
    
    # Run actual backup
    debug_info "Starting actual backup..."
    if eval "$rsync_cmd" > /tmp/rsync_actual.log 2>&1; then
        debug_info "✅ Backup completed successfully"
        debug_info "Backup output:"
        cat /tmp/rsync_actual.log
    else
        debug_info "❌ Backup failed"
        debug_info "Backup error output:"
        cat /tmp/rsync_actual.log
        exit 1
    fi
else
    debug_info "User chose not to proceed with actual backup"
fi

debug_info "=== nrBackup Debug Mode Finished ==="
