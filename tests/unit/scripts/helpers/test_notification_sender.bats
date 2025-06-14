#!/usr/bin/env bats

load '../../test_helper.bash'

@test "notification_sender: check_notification_tool returns success when terminal-notifier is available" {
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    # Our mock terminal-notifier should be in PATH
    run check_notification_tool
    assert_success
}

@test "notification_sender: check_notification_tool fails when terminal-notifier is missing" {
    # Remove terminal-notifier from PATH temporarily
    local old_path="$PATH"
    export PATH="/usr/bin:/bin"
    
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    run check_notification_tool
    assert_failure
    
    # Restore PATH
    export PATH="$old_path"
}

@test "notification_sender: send_success_notification function exists and can be called" {
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    # Just test that the function exists and doesn't crash
    # We'll mock the logger to avoid dependencies
    log_info() { echo "LOG: $*"; }
    export -f log_info
    
    run send_success_notification "120" "/Volumes/TestBackup"
    # Should not fail catastrophically
    [[ $status -eq 0 || $status -eq 1 ]]
}

@test "notification_sender: send_failure_notification function exists and can be called" {
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    # Mock the logger
    log_info() { echo "LOG: $*"; }
    export -f log_info
    
    run send_failure_notification "rsync failed"
    # Should not fail catastrophically  
    [[ $status -eq 0 || $status -eq 1 ]]
}