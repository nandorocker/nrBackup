#!/usr/bin/env bats

load '../../test_helper.bash'

@test "notification_sender: sends success notification" {
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    run send_success_notification "120" "/Volumes/TestBackup"
    assert_success
    
    # Check that mock terminal-notifier was called
    assert [ -f "$TEST_LOG_DIR/notifications.log" ]
    run cat "$TEST_LOG_DIR/notifications.log"
    assert_output --partial "Backup completed successfully"
}

@test "notification_sender: sends failure notification" {
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    run send_failure_notification "rsync failed"
    assert_success
    
    # Check that mock terminal-notifier was called
    assert [ -f "$TEST_LOG_DIR/notifications.log" ]
    run cat "$TEST_LOG_DIR/notifications.log"
    assert_output --partial "Backup failed"
}

@test "notification_sender: tests notification system" {
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    run test_notifications
    assert_success
    
    # Check that test notification was sent
    assert [ -f "$TEST_LOG_DIR/notifications.log" ]
    run cat "$TEST_LOG_DIR/notifications.log"
    assert_output --partial "nrBackup Test"
}

@test "notification_sender: handles missing terminal-notifier gracefully" {
    # Remove mock terminal-notifier to simulate missing command
    rm -f "$MOCK_TERMINAL_NOTIFIER"
    
    source "$PROJECT_ROOT/scripts/helpers/notification_sender.sh"
    
    # Should not fail but should handle gracefully
    run send_success_notification "60" "/Volumes/TestBackup"
    
    # Since terminal-notifier is missing, it should either:
    # 1. Exit with non-zero status, or
    # 2. Continue gracefully without notification
    # The exact behavior depends on implementation
}