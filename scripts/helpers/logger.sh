#!/bin/bash

# nrBackup - Logging Helper
# This script handles all logging functionality

# Global logging variables
LOG_FILE=""
LOG_LEVEL="INFO"

# Initialize logging
init_logging() {
    local log_dir="$HOME/Library/Logs/nrBackup"
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    
    # Create log directory if it doesn't exist
    mkdir -p "$log_dir"
    
    # Set log file path
    LOG_FILE="$log_dir/backup_$timestamp.log"
    
    # Create log file and add header
    {
        echo "=== nrBackup Log Started ==="
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Log File: $LOG_FILE"
        echo "PID: $$"
        echo "User: $(whoami)"
        echo "Host: $(hostname)"
        echo "================================"
        echo ""
    } > "$LOG_FILE"
}

# Log message with timestamp and level
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Initialize logging if not already done
    if [[ -z "$LOG_FILE" ]]; then
        init_logging
    fi
    
    # Format log entry
    local log_entry="[$timestamp] [$level] $message"
    
    # Write to log file
    echo "$log_entry" >> "$LOG_FILE"
    
    # Also output to stderr for interactive sessions
    if [[ -t 2 ]]; then
        case "$level" in
            "ERROR")
                echo -e "\033[31m$log_entry\033[0m" >&2  # Red
                ;;
            "WARNING")
                echo -e "\033[33m$log_entry\033[0m" >&2  # Yellow
                ;;
            "INFO")
                echo "$log_entry" >&2
                ;;
            "DEBUG")
                if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
                    echo -e "\033[36m$log_entry\033[0m" >&2  # Cyan
                fi
                ;;
        esac
    fi
}

# Convenience functions for different log levels
log_info() {
    log_message "INFO" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_debug() {
    log_message "DEBUG" "$1"
}

# Log command execution
log_command() {
    local command="$1"
    log_info "Executing command: $command"
}

# Log file operations
log_file_operation() {
    local operation="$1"
    local file_path="$2"
    log_info "File operation: $operation - $file_path"
}

# Log system information
log_system_info() {
    log_info "=== System Information ==="
    log_info "macOS Version: $(sw_vers -productVersion)"
    log_info "System: $(uname -a)"
    log_info "Available Disk Space:"
    
    # Log disk space for relevant volumes
    df -h / | while IFS= read -r line; do
        log_info "  $line"
    done
    
    # Log mounted volumes
    log_info "Mounted Volumes:"
    mount | grep -E "^/dev/" | while IFS= read -r line; do
        log_info "  $line"
    done
    
    log_info "=========================="
}

# Log configuration summary
log_config_summary() {
    log_info "=== Configuration Summary ==="
    log_info "Schedule Type: $SCHEDULE_TYPE"
    log_info "Destination Drive: $DESTINATION_DRIVE"
    log_info "Detailed Logging: $DETAILED_LOGGING"
    log_info "Source Paths: ${#SOURCE_PATHS[@]} configured"
    log_info "Exclude Paths: ${#EXCLUDE_PATHS[@]} configured"
    log_info "============================="
}

# Log backup statistics
log_backup_stats() {
    local start_time="$1"
    local end_time="$2"
    local success="$3"
    local files_transferred="$4"
    local bytes_transferred="$5"
    
    log_info "=== Backup Statistics ==="
    log_info "Start Time: $start_time"
    log_info "End Time: $end_time"
    log_info "Success: $success"
    
    if [[ -n "$files_transferred" ]]; then
        log_info "Files Transferred: $files_transferred"
    fi
    
    if [[ -n "$bytes_transferred" ]]; then
        log_info "Bytes Transferred: $bytes_transferred"
    fi
    
    log_info "========================="
}

# Rotate old log files (keep last 30 days)
rotate_logs() {
    local log_dir="$HOME/Library/Logs/nrBackup"
    
    if [[ -d "$log_dir" ]]; then
        log_info "Rotating old log files..."
        
        # Find and remove log files older than 30 days
        find "$log_dir" -name "backup_*.log" -type f -mtime +30 -delete
        
        # Count remaining log files
        local log_count
        log_count=$(find "$log_dir" -name "backup_*.log" -type f | wc -l)
        log_info "Log rotation complete. $log_count log files remaining."
    fi
}

# Get current log file path
get_log_file() {
    echo "$LOG_FILE"
}

# Set log level
set_log_level() {
    local level="$1"
    case "$level" in
        "DEBUG"|"INFO"|"WARNING"|"ERROR")
            LOG_LEVEL="$level"
            log_info "Log level set to: $LOG_LEVEL"
            ;;
        *)
            log_warning "Invalid log level: $level. Using INFO."
            LOG_LEVEL="INFO"
            ;;
    esac
}

# Log separator for readability
log_separator() {
    log_info "=================================================="
}

# Log environment variables (for debugging)
log_environment() {
    if [[ "$LOG_LEVEL" == "DEBUG" ]]; then
        log_debug "=== Environment Variables ==="
        log_debug "PATH: $PATH"
        log_debug "HOME: $HOME"
        log_debug "USER: $USER"
        log_debug "SHELL: $SHELL"
        log_debug "PWD: $PWD"
        log_debug "============================="
    fi
}

# Clean up logging (called at script exit)
cleanup_logging() {
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        {
            echo ""
            echo "=== nrBackup Log Ended ==="
            echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "==============================="
        } >> "$LOG_FILE"
    fi
}

# Set up log cleanup on script exit
trap cleanup_logging EXIT
