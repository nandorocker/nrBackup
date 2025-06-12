#!/bin/bash

# nrBackup - Configuration Parser
# This script handles parsing and validation of the JSON configuration file

# Global configuration variables
SCHEDULE_TYPE=""
INTERVAL_HOURS=""
DAILY_BACKUP_TIME=""
SOURCE_PATHS=()
EXCLUDE_PATHS=()
DESTINATION_DRIVE=""
DETAILED_LOGGING=""

# Parse configuration file
parse_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Configuration file not found: $config_file" >&2
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is required but not installed. Please install with: brew install jq" >&2
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$config_file" 2>/dev/null; then
        echo "Error: Invalid JSON in configuration file" >&2
        return 1
    fi
    
    # Parse configuration values
    SCHEDULE_TYPE=$(jq -r '.schedule_type // "interval"' "$config_file")
    INTERVAL_HOURS=$(jq -r '.interval_hours // 6' "$config_file")
    DAILY_BACKUP_TIME=$(jq -r '.daily_backup_time // "02:00"' "$config_file")
    DESTINATION_DRIVE=$(jq -r '.destination_drive_mount_point // "/Volumes/BackupDrive"' "$config_file")
    DETAILED_LOGGING=$(jq -r '.detailed_logging // false' "$config_file")
    
    # Parse source paths array
    local source_count
    source_count=$(jq '.source_paths | length' "$config_file")
    SOURCE_PATHS=()
    for ((i=0; i<source_count; i++)); do
        local path
        path=$(jq -r ".source_paths[$i]" "$config_file")
        # Expand environment variables like $USER
        path=$(eval echo "$path")
        SOURCE_PATHS+=("$path")
    done
    
    # Parse exclude paths array
    local exclude_count
    exclude_count=$(jq '.exclude_paths | length' "$config_file")
    EXCLUDE_PATHS=()
    for ((i=0; i<exclude_count; i++)); do
        local path
        path=$(jq -r ".exclude_paths[$i]" "$config_file")
        # Expand environment variables like $USER
        path=$(eval echo "$path")
        EXCLUDE_PATHS+=("$path")
    done
    
    # Validate configuration
    if ! validate_config; then
        return 1
    fi
    
    return 0
}

# Validate parsed configuration
validate_config() {
    # Validate schedule type
    case "$SCHEDULE_TYPE" in
        "interval"|"daily_at_time"|"on_drive_connect"|"hybrid")
            ;;
        *)
            echo "Error: Invalid schedule_type '$SCHEDULE_TYPE'. Must be one of: interval, daily_at_time, on_drive_connect, hybrid" >&2
            return 1
            ;;
    esac
    
    # Validate interval hours
    if [[ "$SCHEDULE_TYPE" == "interval" || "$SCHEDULE_TYPE" == "hybrid" ]]; then
        if ! [[ "$INTERVAL_HOURS" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_HOURS" -lt 1 ]]; then
            echo "Error: interval_hours must be a positive integer" >&2
            return 1
        fi
    fi
    
    # Validate daily backup time format
    if [[ "$SCHEDULE_TYPE" == "daily_at_time" || "$SCHEDULE_TYPE" == "hybrid" ]]; then
        if ! [[ "$DAILY_BACKUP_TIME" =~ ^[0-2][0-9]:[0-5][0-9]$ ]]; then
            echo "Error: daily_backup_time must be in HH:MM format (24-hour)" >&2
            return 1
        fi
    fi
    
    # Validate source paths
    if [[ ${#SOURCE_PATHS[@]} -eq 0 ]]; then
        echo "Error: At least one source path must be specified" >&2
        return 1
    fi
    
    # Validate detailed logging
    if [[ "$DETAILED_LOGGING" != "true" && "$DETAILED_LOGGING" != "false" ]]; then
        echo "Error: detailed_logging must be true or false" >&2
        return 1
    fi
    
    return 0
}

# Generate default configuration
generate_default_config() {
    local config_file="$1"
    local config_dir
    config_dir=$(dirname "$config_file")
    
    # Create directory if it doesn't exist
    mkdir -p "$config_dir"
    
    # Get current user for default paths
    local current_user
    current_user=$(whoami)
    
    cat > "$config_file" << EOF
{
  "schedule_type": "hybrid",
  "interval_hours": 6,
  "daily_backup_time": "02:00",
  "source_paths": [
    "/Users/$current_user"
  ],
  "exclude_paths": [
    "/Users/$current_user/Downloads",
    "/Users/$current_user/Library/Caches",
    "/Users/$current_user/.Trash",
    "/Users/$current_user/.npm",
    "/Users/$current_user/.yarn",
    "**/.DS_Store",
    "**/node_modules",
    "**/.git",
    "**/*.tmp",
    "**/*.temp",
    "**/Thumbs.db",
    "**/.localized"
  ],
  "destination_drive_mount_point": "/Volumes/BackupDrive",
  "detailed_logging": false
}
EOF
    
    echo "Default configuration created at: $config_file"
    return 0
}

# Display current configuration
display_config() {
    echo "=== Current Configuration ==="
    echo "Schedule Type: $SCHEDULE_TYPE"
    
    if [[ "$SCHEDULE_TYPE" == "interval" || "$SCHEDULE_TYPE" == "hybrid" ]]; then
        echo "Interval Hours: $INTERVAL_HOURS"
    fi
    
    if [[ "$SCHEDULE_TYPE" == "daily_at_time" || "$SCHEDULE_TYPE" == "hybrid" ]]; then
        echo "Daily Backup Time: $DAILY_BACKUP_TIME"
    fi
    
    echo "Destination Drive: $DESTINATION_DRIVE"
    echo "Detailed Logging: $DETAILED_LOGGING"
    
    echo "Source Paths:"
    for path in "${SOURCE_PATHS[@]}"; do
        echo "  - $path"
    done
    
    echo "Exclude Paths:"
    for path in "${EXCLUDE_PATHS[@]}"; do
        echo "  - $path"
    done
    
    echo "=========================="
}

# Check if configuration file exists and is valid
check_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Configuration file not found: $config_file"
        return 1
    fi
    
    if parse_config "$config_file"; then
        echo "Configuration is valid"
        display_config
        return 0
    else
        echo "Configuration is invalid"
        return 1
    fi
}
