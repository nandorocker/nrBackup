#!/usr/bin/env bats

load '../test_helper.bash'

@test "backup_main: validates environment before backup" {
    # Create test config and directories
    local test_config="$TEST_CONFIG_DIR/config.json"
    create_test_config "$test_config"
    mkdir -p "$TEST_BACKUP_DIR/TestBackup"
    mkdir -p "$TEST_TEMP_DIR/testuser"
    
    # Set up environment variables
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    # Source the backup main script (but don't run main function)
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Set required variables and parse config
    COMPUTER_NAME=$(hostname -s)
    parse_config "$CONFIG_FILE"
    
    # Test validate_environment function - should succeed with proper setup
    # Check the destination exists
    [[ -d "$DESTINATION_DRIVE" ]]
    
    # Run the actual validation
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
    mkdir -p "$TEST_BACKUP_DIR/TestBackup"
    mkdir -p "$TEST_TEMP_DIR/testuser"
    
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Set required variables and parse config
    COMPUTER_NAME=$(hostname -s)
    parse_config "$CONFIG_FILE"
    
    # Test rsync command generation
    run build_rsync_command
    assert_success
    assert_output --partial "rsync -aH"
    assert_output --partial "--delete"
    assert_output --partial "--exclude='Downloads'"
    assert_output --partial "$TEST_TEMP_DIR/testuser/"
    assert_output --partial "$TEST_BACKUP_DIR/TestBackup/Backups/"
}

@test "backup_main: performs backup with mocked rsync" {
    # Create test environment
    local test_config="$TEST_CONFIG_DIR/config.json"
    create_test_config "$test_config"
    mkdir -p "$TEST_BACKUP_DIR/TestBackup/Backups/$(hostname -s)"
    mkdir -p "$TEST_TEMP_DIR/testuser"
    
    export APP_SUPPORT_DIR="$TEST_CONFIG_DIR"
    export CONFIG_FILE="$test_config"
    export LOG_DIR="$TEST_LOG_DIR"
    export HELPERS_DIR="$PROJECT_ROOT/scripts/helpers"
    
    source "$PROJECT_ROOT/scripts/backup_main.sh"
    
    # Set required variables and parse config
    COMPUTER_NAME=$(hostname -s)
    parse_config "$CONFIG_FILE"
    
    # Set destination path that would be set by validate_environment
    DESTINATION_PATH="$DESTINATION_DRIVE/Backups/$COMPUTER_NAME"
    
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
    
    # Set required variables
    COMPUTER_NAME=$(hostname -s)
    
    # Should fail when config file doesn't exist
    run validate_environment
    assert_failure
}