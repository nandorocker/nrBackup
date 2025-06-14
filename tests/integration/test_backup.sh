#!/bin/bash

# nrBackup - Test Version for Local Development
# This script tests the backup functionality using source files directly

set -euo pipefail

# Enable debug mode
set -x

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_CONFIG_DIR="$SCRIPT_DIR/../config"
TEST_CONFIG_FILE="$TEST_CONFIG_DIR/config.json"
TEST_LOG_DIR="$TEST_CONFIG_DIR/logs"
HELPERS_DIR="$SCRIPT_DIR/scripts/helpers"

# Debug output function
debug_info() {
    echo "DEBUG: $1" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $1"
}

debug_info "=== nrBackup Test Mode Started ==="
debug_info "Script directory: $SCRIPT_DIR"
debug_info "Test config file: $TEST_CONFIG_FILE"
debug_info "Test log directory: $TEST_LOG_DIR"
debug_info "Helpers directory: $HELPERS_DIR"

# Create test directories
mkdir -p "$TEST_CONFIG_DIR"
mkdir -p "$TEST_LOG_DIR"

# Create a test configuration file
debug_info "Creating test configuration..."
cat > "$TEST_CONFIG_FILE" << 'EOF'
{
  "schedule_type": "interval",
  "interval_hours": 6,
  "daily_backup_time": "02:00",
  "source_paths": ["/Users/nando/Documents/test_backup_source"],
  "exclude_paths": [
    "Downloads",
    ".Trash",
    "**/.DS_Store",
    "**/node_modules",
    "**/.git"
  ],
  "destination_drive_mount_point": "/Volumes/Beck 1Tb",
  "detailed_logging": true
}
EOF

# Create a small test source directory
TEST_SOURCE_DIR="/Users/nando/Documents/test_backup_source"
if [[ ! -d "$TEST_SOURCE_DIR" ]]; then
    debug_info "Creating test source directory: $TEST_SOURCE_DIR"
    mkdir -p "$TEST_SOURCE_DIR"
    echo "This is a test file for backup" > "$TEST_SOURCE_DIR/test_file.txt"
    echo "Another test file" > "$TEST_SOURCE_DIR/test_file2.txt"
    mkdir -p "$TEST_SOURCE_DIR/subdir"
    echo "File in subdirectory" > "$TEST_SOURCE_DIR/subdir/subfile.txt"
fi

# Source helper scripts
debug_info "Sourcing helper scripts..."
source "$HELPERS_DIR/config_parser.sh"
source "$HELPERS_DIR/logger.sh"
source "$HELPERS_DIR/notification_sender.sh"

# Override some environment variables for testing
export LOG_DIR="$TEST_LOG_DIR"
export LOG_FILE="$TEST_LOG_DIR/test_backup.log"

# Test configuration parsing
debug_info "Testing configuration parsing..."
if parse_config "$TEST_CONFIG_FILE"; then
    debug_info "✅ Configuration parsed successfully"
    debug_info "Schedule type: $SCHEDULE_TYPE"
    debug_info "Destination drive: $DESTINATION_DRIVE"
    debug_info "Source paths: ${SOURCE_PATHS[*]}"
    debug_info "Number of exclude paths: ${#EXCLUDE_PATHS[@]}"
    debug_info "Detailed logging: $DETAILED_LOGGING"
else
    debug_info "❌ Configuration parsing failed"
    exit 1
fi

# Check destination drive
debug_info "Checking destination drive..."
if [[ -d "$DESTINATION_DRIVE" ]]; then
    debug_info "✅ Destination drive mounted: $DESTINATION_DRIVE"
    debug_info "Free space on destination:"
    df -h "$DESTINATION_DRIVE" | tail -1
else
    debug_info "❌ Destination drive not found: $DESTINATION_DRIVE"
    debug_info "Available volumes:"
    ls -la /Volumes/ 2>/dev/null || debug_info "Cannot list /Volumes/"
    exit 1
fi

# Check source paths
debug_info "Checking source paths..."
for source in "${SOURCE_PATHS[@]}"; do
    if [[ -d "$source" ]]; then
        debug_info "✅ Source path exists: $source"
        debug_info "Source path contents:"
        ls -la "$source"
        debug_info "Source path size: $(du -sh "$source" 2>/dev/null | cut -f1 || echo "unknown")"
    else
        debug_info "❌ Source path not found: $source"
        exit 1
    fi
done

# Test rsync command
debug_info "Testing rsync command..."
COMPUTER_NAME=$(hostname -s)
DESTINATION_PATH="$DESTINATION_DRIVE/Backups/Test_$COMPUTER_NAME"

debug_info "Computer name: $COMPUTER_NAME"
debug_info "Destination path: $DESTINATION_PATH"

# Create destination directory
mkdir -p "$DESTINATION_PATH"

# Build rsync command (using compatible flags for macOS)
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
    debug_info "Dry-run output:"
    cat /tmp/rsync_dryrun.log
else
    debug_info "❌ Dry-run failed"
    debug_info "Dry-run error output:"
    cat /tmp/rsync_dryrun.log
    exit 1
fi

# Ask user if they want to proceed with actual backup
echo ""
echo "TEST MODE: Dry-run completed successfully."
echo "Would you like to proceed with the actual test backup? (y/N)"
read -r proceed

if [[ "$proceed" =~ ^[Yy] ]]; then
    debug_info "Proceeding with actual test backup..."
    
    # Run actual backup
    debug_info "Starting actual backup..."
    if eval "$rsync_cmd" > /tmp/rsync_actual.log 2>&1; then
        debug_info "✅ Backup completed successfully"
        debug_info "Backup output:"
        cat /tmp/rsync_actual.log
        
        debug_info "Verifying backup..."
        debug_info "Destination contents:"
        ls -la "$DESTINATION_PATH"
        
        debug_info "Test completed successfully!"
    else
        debug_info "❌ Backup failed"
        debug_info "Backup error output:"
        cat /tmp/rsync_actual.log
        exit 1
    fi
else
    debug_info "User chose not to proceed with actual backup"
fi

debug_info "=== nrBackup Test Mode Finished ==="
