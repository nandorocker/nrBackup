#!/usr/bin/env bash

# Load bats libraries
load '../../../test/test_helper/bats-support/load'
load '../../../test/test_helper/bats-assert/load'

# Test environment setup
export BATS_TEST_DIRNAME="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
export PROJECT_ROOT="$BATS_TEST_DIRNAME/../../.."

# Test directories
export TEST_TEMP_DIR="$BATS_TEST_DIRNAME/tmp"
export TEST_CONFIG_DIR="$TEST_TEMP_DIR/config"
export TEST_LOG_DIR="$TEST_TEMP_DIR/logs"
export TEST_BACKUP_DIR="$TEST_TEMP_DIR/backup"

# Mock external dependencies
export MOCK_JQ="$TEST_TEMP_DIR/mock_jq"
export MOCK_TERMINAL_NOTIFIER="$TEST_TEMP_DIR/mock_terminal_notifier"
export MOCK_RSYNC="$TEST_TEMP_DIR/mock_rsync"

function setup() {
    # Create test directories
    mkdir -p "$TEST_TEMP_DIR"
    mkdir -p "$TEST_CONFIG_DIR"
    mkdir -p "$TEST_LOG_DIR"
    mkdir -p "$TEST_BACKUP_DIR"
    
    # Create mock executables
    create_mock_jq
    create_mock_terminal_notifier
    create_mock_rsync
    
    # Add mocks to PATH
    export PATH="$TEST_TEMP_DIR:$PATH"
}

function teardown() {
    # Clean up test environment
    if [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

function create_mock_jq() {
    cat > "$MOCK_JQ" << 'EOF'
#!/bin/bash
# Mock jq for testing
case "$1" in
    "empty")
        # Validate JSON syntax
        exit 0
        ;;
    "-r")
        case "$2" in
            ".schedule_type // \"interval\"")
                echo "interval"
                ;;
            ".interval_hours // 6")
                echo "6"
                ;;
            ".daily_backup_time // \"02:00\"")
                echo "02:00"
                ;;
            ".destination_drive_mount_point // \"/Volumes/BackupDrive\"")
                echo "/Volumes/TestBackup"
                ;;
            ".detailed_logging // false")
                echo "false"
                ;;
            ".source_paths | length")
                echo "1"
                ;;
            ".source_paths[0]")
                echo "/Users/testuser"
                ;;
            ".exclude_paths | length")
                echo "3"
                ;;
            ".exclude_paths[0]")
                echo "Downloads"
                ;;
            ".exclude_paths[1]")
                echo ".Trash"
                ;;
            ".exclude_paths[2]")
                echo "**/.DS_Store"
                ;;
        esac
        ;;
esac
EOF
    chmod +x "$MOCK_JQ"
}

function create_mock_terminal_notifier() {
    cat > "$MOCK_TERMINAL_NOTIFIER" << 'EOF'
#!/bin/bash
# Mock terminal-notifier for testing
echo "Mock notification: $*" > "$TEST_LOG_DIR/notifications.log"
exit 0
EOF
    chmod +x "$MOCK_TERMINAL_NOTIFIER"
}

function create_mock_rsync() {
    cat > "$MOCK_RSYNC" << 'EOF'
#!/bin/bash
# Mock rsync for testing
echo "Mock rsync executed with args: $*" > "$TEST_LOG_DIR/rsync.log"

# Simulate rsync stats output
cat << 'RSYNC_STATS'
Number of files: 1000
Number of created files: 50
Number of deleted files: 5
Total file size: 1,048,576 bytes
Total transferred file size: 52,428 bytes
RSYNC_STATS

exit 0
EOF
    chmod +x "$MOCK_RSYNC"
}

function create_test_config() {
    local config_file="$1"
    cat > "$config_file" << 'EOF'
{
  "schedule_type": "interval",
  "interval_hours": 6,
  "daily_backup_time": "02:00",
  "source_paths": ["/Users/testuser"],
  "exclude_paths": [
    "Downloads",
    ".Trash",
    "**/.DS_Store"
  ],
  "destination_drive_mount_point": "/Volumes/TestBackup",
  "detailed_logging": false
}
EOF
}

function create_invalid_config() {
    local config_file="$1"
    cat > "$config_file" << 'EOF'
{
  "schedule_type": "interval",
  "interval_hours": 6,
  "invalid_json": 
}
EOF
}