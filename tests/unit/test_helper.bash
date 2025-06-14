#!/usr/bin/env bash

# Find the project root dynamically
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
PROJECT_ROOT="$( cd "$CURRENT_DIR/.." >/dev/null 2>&1 && pwd )"

# Load bats libraries
load "$PROJECT_ROOT/tests/framework/test_helper/bats-support/load"
load "$PROJECT_ROOT/tests/framework/test_helper/bats-assert/load"

# Test environment setup
export BATS_TEST_DIRNAME="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
export PROJECT_ROOT="$PROJECT_ROOT"

# Test directories
export TEST_TEMP_DIR="$BATS_TEST_DIRNAME/tmp"
export TEST_CONFIG_DIR="$TEST_TEMP_DIR/config"
export TEST_LOG_DIR="$TEST_TEMP_DIR/logs"
export TEST_BACKUP_DIR="$TEST_TEMP_DIR/backup"

# Mock external dependencies
export MOCK_JQ="$TEST_TEMP_DIR/jq"
export MOCK_TERMINAL_NOTIFIER="$TEST_TEMP_DIR/terminal-notifier"
export MOCK_RSYNC="$TEST_TEMP_DIR/rsync"

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
    
    # Add mocks to PATH at the beginning so they take precedence
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
if [[ $# -eq 2 && "$1" == "empty" ]]; then
    # Validate JSON syntax - check if file contains invalid JSON patterns
    config_file="$2"
    if [[ -f "$config_file" ]] && grep -q "invalid_json".*:.*$ "$config_file"; then
        echo "Invalid JSON in configuration file" >&2
        exit 1
    fi
    exit 0
elif [[ "$1" == "-r" ]]; then
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
            echo "$TEST_BACKUP_DIR/TestBackup"
            ;;
        ".detailed_logging // false")
            echo "false"
            ;;
        ".source_paths[0]")
            echo "$TEST_TEMP_DIR/testuser"
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
        *)
            # Default fallback for any other queries
            echo ""
            ;;
    esac
elif [[ "$1" =~ ^\. && "$1" =~ length$ ]]; then
    case "$1" in
        ".source_paths | length")
            echo "1"
            ;;
        ".exclude_paths | length")
            echo "3"
            ;;
        *)
            echo "0"
            ;;
    esac
else
    # For any other case, try to parse the actual file if it exists
    if [[ -f "$3" ]]; then
        # Use real jq if available, otherwise provide default
        if command -v /usr/bin/jq >/dev/null 2>&1; then
            /usr/bin/jq "$@"
        else
            echo ""
        fi
    else
        echo ""
    fi
fi
EOF
    chmod +x "$MOCK_JQ"
}

function create_mock_terminal_notifier() {
    cat > "$MOCK_TERMINAL_NOTIFIER" << 'EOF'
#!/bin/bash
# Mock terminal-notifier for testing
# Log all arguments passed to terminal-notifier
mkdir -p "$(dirname "${TEST_LOG_DIR:-/tmp}/notifications.log")" 2>/dev/null || true
echo "Mock notification: $*" >> "${TEST_LOG_DIR:-/tmp}/notifications.log"
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
    cat > "$config_file" << EOF
{
  "schedule_type": "interval",
  "interval_hours": 6,
  "daily_backup_time": "02:00",
  "source_paths": ["$TEST_TEMP_DIR/testuser"],
  "exclude_paths": [
    "Downloads",
    ".Trash",
    "**/.DS_Store"
  ],
  "destination_drive_mount_point": "$TEST_BACKUP_DIR/TestBackup",
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