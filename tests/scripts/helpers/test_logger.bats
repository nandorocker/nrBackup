#!/usr/bin/env bats

load '../../test_helper.bash'

@test "logger: creates log file and writes info messages" {
    # Set up log environment
    export LOG_DIR="$TEST_LOG_DIR"
    export LOG_FILE="$TEST_LOG_DIR/test.log"
    
    source "$PROJECT_ROOT/scripts/helpers/logger.sh"
    
    # Test info logging
    run log_info "Test info message"
    assert_success
    
    # Check log file was created and contains message
    assert [ -f "$LOG_FILE" ]
    run cat "$LOG_FILE"
    assert_output --partial "[INFO] Test info message"
}

@test "logger: writes error messages with ERROR level" {
    export LOG_DIR="$TEST_LOG_DIR"
    export LOG_FILE="$TEST_LOG_DIR/test.log"
    
    source "$PROJECT_ROOT/scripts/helpers/logger.sh"
    
    run log_error "Test error message"
    assert_success
    
    run cat "$LOG_FILE"
    assert_output --partial "[ERROR] Test error message"
}

@test "logger: writes warning messages with WARNING level" {
    export LOG_DIR="$TEST_LOG_DIR"
    export LOG_FILE="$TEST_LOG_DIR/test.log"
    
    source "$PROJECT_ROOT/scripts/helpers/logger.sh"
    
    run log_warning "Test warning message"
    assert_success
    
    run cat "$LOG_FILE"
    assert_output --partial "[WARNING] Test warning message"
}

@test "logger: includes timestamp in log entries" {
    export LOG_DIR="$TEST_LOG_DIR"
    export LOG_FILE="$TEST_LOG_DIR/test.log"
    
    source "$PROJECT_ROOT/scripts/helpers/logger.sh"
    
    log_info "Timestamp test"
    
    # Check that log contains a timestamp pattern
    run grep -E '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$LOG_FILE"
    assert_success
}

@test "logger: handles missing log directory" {
    export LOG_DIR="/nonexistent/directory"
    export LOG_FILE="/nonexistent/directory/test.log"
    
    source "$PROJECT_ROOT/scripts/helpers/logger.sh"
    
    # Should create directory and log successfully
    run log_info "Test message"
    assert_success
}