#!/bin/bash

# nrBackup - Notification Sender
# This script handles sending macOS native notifications

# Check if terminal-notifier is available
check_notification_tool() {
    if ! command -v terminal-notifier &> /dev/null; then
        log_warning "terminal-notifier not found. Install with: brew install terminal-notifier"
        return 1
    fi
    return 0
}

# Send a success notification
send_success_notification() {
    local duration="$1"
    local destination="$2"
    
    # Format duration
    local duration_text
    if [[ "$duration" -lt 60 ]]; then
        duration_text="${duration} seconds"
    elif [[ "$duration" -lt 3600 ]]; then
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        duration_text="${minutes}m ${seconds}s"
    else
        local hours=$((duration / 3600))
        local minutes=$(((duration % 3600) / 60))
        duration_text="${hours}h ${minutes}m"
    fi
    
    local title="nrBackup - Success"
    local message="Backup completed successfully in $duration_text"
    local subtitle="Destination: $(basename "$destination")"
    
    log_info "Sending success notification: $message"
    
    if check_notification_tool; then
        terminal-notifier \
            -title "$title" \
            -subtitle "$subtitle" \
            -message "$message" \
            -sound "Glass" \
            -group "nrBackup" \
            -sender "com.apple.backup" \
            -activate "com.apple.finder" \
            -execute "open '$destination'" \
            > /dev/null 2>&1
    else
        # Fallback to system notification if terminal-notifier is not available
        osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" sound name \"Glass\"" 2>/dev/null || true
    fi
}

# Send a failure notification
send_failure_notification() {
    local error_message="$1"
    
    local title="nrBackup - Failed"
    local message="Backup failed: $error_message"
    local subtitle="Check logs for details"
    
    log_info "Sending failure notification: $message"
    
    if check_notification_tool; then
        terminal-notifier \
            -title "$title" \
            -subtitle "$subtitle" \
            -message "$message" \
            -sound "Basso" \
            -group "nrBackup" \
            -sender "com.apple.backup" \
            -activate "com.apple.console" \
            -execute "open '$HOME/Library/Logs/nrBackup'" \
            > /dev/null 2>&1
    else
        # Fallback to system notification if terminal-notifier is not available
        osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" sound name \"Basso\"" 2>/dev/null || true
    fi
}

# Send a warning notification
send_warning_notification() {
    local warning_message="$1"
    
    local title="nrBackup - Warning"
    local message="$warning_message"
    local subtitle="Backup may be incomplete"
    
    log_info "Sending warning notification: $message"
    
    if check_notification_tool; then
        terminal-notifier \
            -title "$title" \
            -subtitle "$subtitle" \
            -message "$message" \
            -sound "Purr" \
            -group "nrBackup" \
            -sender "com.apple.backup" \
            > /dev/null 2>&1
    else
        # Fallback to system notification if terminal-notifier is not available
        osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\" sound name \"Purr\"" 2>/dev/null || true
    fi
}

# Send an info notification
send_info_notification() {
    local info_message="$1"
    
    local title="nrBackup - Info"
    local message="$info_message"
    
    log_info "Sending info notification: $message"
    
    if check_notification_tool; then
        terminal-notifier \
            -title "$title" \
            -message "$message" \
            -sound "Blow" \
            -group "nrBackup" \
            -sender "com.apple.backup" \
            > /dev/null 2>&1
    else
        # Fallback to system notification if terminal-notifier is not available
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"Blow\"" 2>/dev/null || true
    fi
}

# Send a backup started notification (optional)
send_backup_started_notification() {
    local source_count="$1"
    local destination="$2"
    
    local title="nrBackup - Started"
    local message="Backing up $source_count source(s)"
    local subtitle="To: $(basename "$destination")"
    
    log_info "Sending backup started notification"
    
    if check_notification_tool; then
        terminal-notifier \
            -title "$title" \
            -subtitle "$subtitle" \
            -message "$message" \
            -group "nrBackup" \
            -sender "com.apple.backup" \
            > /dev/null 2>&1
    else
        # Fallback to system notification if terminal-notifier is not available
        osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\"" 2>/dev/null || true
    fi
}

# Send drive connection notification
send_drive_connected_notification() {
    local drive_name="$1"
    
    local title="nrBackup - Drive Connected"
    local message="Backup drive '$drive_name' connected"
    local subtitle="Backup will start shortly"
    
    log_info "Sending drive connected notification"
    
    if check_notification_tool; then
        terminal-notifier \
            -title "$title" \
            -subtitle "$subtitle" \
            -message "$message" \
            -group "nrBackup" \
            -sender "com.apple.backup" \
            > /dev/null 2>&1
    else
        # Fallback to system notification if terminal-notifier is not available
        osascript -e "display notification \"$message\" with title \"$title\" subtitle \"$subtitle\"" 2>/dev/null || true
    fi
}

# Clear all nrBackup notifications
clear_notifications() {
    if check_notification_tool; then
        terminal-notifier -remove "nrBackup" > /dev/null 2>&1
        log_info "Cleared all nrBackup notifications"
    fi
}

# Test notification system
test_notifications() {
    log_info "Testing notification system..."
    
    if check_notification_tool; then
        send_info_notification "Notification system test - terminal-notifier available"
        log_info "Test notification sent using terminal-notifier"
        return 0
    else
        # Test fallback notification
        if osascript -e "display notification \"Notification system test - using fallback\" with title \"nrBackup - Test\"" 2>/dev/null; then
            log_info "Test notification sent using fallback method"
            return 0
        else
            log_error "Notification system test failed"
            return 1
        fi
    fi
}

# Get notification preferences (for future use)
get_notification_preferences() {
    # This could be extended to read user preferences for notification types
    # For now, return default settings
    echo "all"  # Options: all, errors_only, none
}

# Send notification based on preferences
send_conditional_notification() {
    local notification_type="$1"  # success, failure, warning, info
    shift
    local args=("$@")
    
    local preferences
    preferences=$(get_notification_preferences)
    
    case "$preferences" in
        "all")
            case "$notification_type" in
                "success") send_success_notification "${args[@]}" ;;
                "failure") send_failure_notification "${args[@]}" ;;
                "warning") send_warning_notification "${args[@]}" ;;
                "info") send_info_notification "${args[@]}" ;;
            esac
            ;;
        "errors_only")
            case "$notification_type" in
                "failure") send_failure_notification "${args[@]}" ;;
                "warning") send_warning_notification "${args[@]}" ;;
            esac
            ;;
        "none")
            log_info "Notifications disabled by user preference"
            ;;
    esac
}

# Format file size for notifications
format_file_size() {
    local bytes="$1"
    
    if [[ "$bytes" -lt 1024 ]]; then
        echo "${bytes} B"
    elif [[ "$bytes" -lt 1048576 ]]; then
        echo "$((bytes / 1024)) KB"
    elif [[ "$bytes" -lt 1073741824 ]]; then
        echo "$((bytes / 1048576)) MB"
    else
        echo "$((bytes / 1073741824)) GB"
    fi
}
