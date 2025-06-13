#!/bin/bash

# nrBackup - Auto Test Version 
# This script automatically runs the backup test without prompting

set -euo pipefail

# Script directory and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_CONFIG_DIR="$SCRIPT_DIR/test_config"
TEST_CONFIG_FILE="$TEST_CONFIG_DIR/config.json"
TEST_LOG_DIR="$TEST_CONFIG_DIR/logs"
HELPERS_DIR="$SCRIPT_DIR/scripts/helpers"

echo "=== nrBackup Auto Test Started ==="

# Create test directories
mkdir -p "$TEST_CONFIG_DIR"
mkdir -p "$TEST_LOG_DIR"

# Create a test configuration file
echo "Creating test configuration..."
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
    echo "Creating test source directory: $TEST_SOURCE_DIR"
    mkdir -p "$TEST_SOURCE_DIR"
    echo "This is a test file for backup $(date)" > "$TEST_SOURCE_DIR/test_file.txt"
    echo "Another test file $(date)" > "$TEST_SOURCE_DIR/test_file2.txt"
    mkdir -p "$TEST_SOURCE_DIR/subdir"
    echo "File in subdirectory $(date)" > "$TEST_SOURCE_DIR/subdir/subfile.txt"
fi

# Source helper scripts
echo "Loading helper scripts..."
source "$HELPERS_DIR/config_parser.sh"
source "$HELPERS_DIR/logger.sh"
source "$HELPERS_DIR/notification_sender.sh"

# Override environment variables for testing
export LOG_DIR="$TEST_LOG_DIR"
export LOG_FILE="$TEST_LOG_DIR/test_backup.log"

# Parse configuration
echo "Parsing configuration..."
if parse_config "$TEST_CONFIG_FILE"; then
    echo "✅ Configuration parsed successfully"
    echo "   Schedule type: $SCHEDULE_TYPE"
    echo "   Destination drive: $DESTINATION_DRIVE"
    echo "   Source paths: ${SOURCE_PATHS[*]}"
    echo "   Exclude paths: ${#EXCLUDE_PATHS[@]} items"
    echo "   Detailed logging: $DETAILED_LOGGING"
else
    echo "❌ Configuration parsing failed"
    exit 1
fi

# Check destination drive
echo "Checking destination drive..."
if [[ -d "$DESTINATION_DRIVE" ]]; then
    echo "✅ Destination drive mounted: $DESTINATION_DRIVE"
    echo "Free space: $(df -h "$DESTINATION_DRIVE" | tail -1 | awk '{print $4}')"
else
    echo "❌ Destination drive not found: $DESTINATION_DRIVE"
    echo "Available volumes:"
    ls -la /Volumes/ 2>/dev/null || echo "Cannot list /Volumes/"
    exit 1
fi

# Check source paths
echo "Checking source paths..."
for source in "${SOURCE_PATHS[@]}"; do
    if [[ -d "$source" ]]; then
        echo "✅ Source path exists: $source"
        echo "   Size: $(du -sh "$source" 2>/dev/null | cut -f1 || echo "unknown")"
        echo "   Files: $(find "$source" -type f | wc -l | tr -d ' ')"
    else
        echo "❌ Source path not found: $source"
        exit 1
    fi
done

# Set up rsync command
COMPUTER_NAME=$(hostname -s)
DESTINATION_PATH="$DESTINATION_DRIVE/Backups/Test_$COMPUTER_NAME"

echo "Creating destination directory: $DESTINATION_PATH"
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

echo "Rsync command: $rsync_cmd"

# Test with dry-run first
echo ""
echo "=== Running dry-run test ==="
dry_run_cmd="${rsync_cmd} --dry-run"
if eval "$dry_run_cmd" > /tmp/rsync_dryrun.log 2>&1; then
    echo "✅ Dry-run successful"
    echo "Files to be transferred:"
    grep -E "^>f" /tmp/rsync_dryrun.log | head -10 || echo "No files to transfer"
    echo ""
    echo "Summary:"
    grep -E "(Number of files|Total file size)" /tmp/rsync_dryrun.log || echo "No summary available"
else
    echo "❌ Dry-run failed"
    echo "Error output:"
    cat /tmp/rsync_dryrun.log
    exit 1
fi

# Run actual backup
echo ""
echo "=== Running actual backup ==="
if eval "$rsync_cmd" > /tmp/rsync_actual.log 2>&1; then
    echo "✅ Backup completed successfully!"
    echo ""
    echo "Backup statistics:"
    grep -E "(Number of files|Total file size|Total transferred)" /tmp/rsync_actual.log
    
    echo ""
    echo "Verifying backup in destination:"
    ls -la "$DESTINATION_PATH"
    
    if [[ -f "$DESTINATION_PATH/test_file.txt" ]]; then
        echo ""
        echo "Sample file content verification:"
        echo "Original: $(cat "$TEST_SOURCE_DIR/test_file.txt")"
        echo "Backup:   $(cat "$DESTINATION_PATH/test_file.txt")"
        
        if diff "$TEST_SOURCE_DIR/test_file.txt" "$DESTINATION_PATH/test_file.txt" > /dev/null; then
            echo "✅ File content matches!"
        else
            echo "❌ File content differs!"
        fi
    fi
    
    echo ""
    echo "=== Backup Test SUCCESSFUL ==="
else
    echo "❌ Backup failed"
    echo "Error output:"
    cat /tmp/rsync_actual.log
    exit 1
fi

echo ""
echo "=== Test completed at $(date) ==="
