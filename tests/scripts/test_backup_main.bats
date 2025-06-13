#!/usr/bin/env bats

load '../test_helper.bash'

@test "backup_main: validates environment before backup" {
    # Create test config and directories
    local test_config="$TEST_CONFIG_DIR/config.json"
    create_test_config "$test_config"
    mkdir -p "/Volumes/TestBackup"
    mkdir -p "/Users/testuser"
    
    # Set up environment variables
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    # Source the backup main script (but don't run main function)
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Test validate_environment function
    run validate_environment
    assert_success
}

@test "backup_main: fails when destination drive not mounted" {
    # Create test config but don't create destination directory
    local test_config="$TEST_CONFIG_DIR/config.json"
    create_test_config "$test_config"
    
    # Set up environment variables
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Should fail because destination drive doesn't exist
    run validate_environment
    assert_failure
}

@test "backup_main: builds correct rsync command" {
    # Create test environment
    local test_config="$TEST_CONFIG_DIR/config.json"
    create_test_config "$test_config"
    mkdir -p "/Volumes/TestBackup"
    mkdir -p "/Users/testuser"
    
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Initialize required variables
    initialize_backup
    validate_environment
    
    # Test rsync command generation
    run build_rsync_command
    assert_success
    assert_output --partial "rsync -aH"
    assert_output --partial "--delete"
    assert_output --partial "--exclude='Downloads'"
    assert_output --partial "/Users/testuser/"
    assert_output --partial "/Volumes/TestBackup/Backups/"
}

@test "backup_main: performs backup with mocked rsync" {
    # Create test environment
    local test_config="$TEST_CONFIG_DIR/config.json"
    create_test_config "$test_config"
    mkdir -p "/Volumes/TestBackup/Backups/$(hostname -s)"
    mkdir -p "/Users/testuser"
    
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Initialize and validate
    initialize_backup
    validate_environment
    
    # Test backup execution
    run perform_backup
    assert_success
    
    # Check that mock rsync was called
    assert [ -f "$TEST_LOG_DIR/rsync.log" ]
    run cat "$TEST_LOG_DIR/rsync.log"
    assert_output --partial "Mock rsync executed"
}

@test "backup_main: handles configuration file not found" {
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="/nonexistent/config.json"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    initialize_backup
    
    # Should fail when config file doesn't exist
    run validate_environment
    assert_failure
}
}