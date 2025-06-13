#!/usr/bin/env bats

load 'test_helper.bash'

@test "setup: checks prerequisites correctly" {
    # Source setup script functions
    source "$PROJECT_ROOT/setup.sh"
    
    # This test would normally fail because jq and terminal-notifier
    # might not be available, but our mocks should make it pass
    run check_prerequisites
    assert_success
}

@test "setup: creates directory structure" {
    source "$PROJECT_ROOT/setup.sh"
    
    # Override directories to use test locations
    export APP_SUPPORT_DIR="$TEST_TEMP_DIR/nrBackup"
    export SCRIPTS_DIR="$APP_SUPPORT_DIR/scripts"
    export HELPERS_DIR="$SCRIPTS_DIR/helpers"
    export LOG_DIR="$TEST_TEMP_DIR/logs"
    
    run create_directories
    assert_success
    
    # Verify directories were created
    assert [ -d "$APP_SUPPORT_DIR" ]
    assert [ -d "$SCRIPTS_DIR" ]
    assert [ -d "$HELPERS_DIR" ]
    assert [ -d "$LOG_DIR" ]
}

@test "setup: copies scripts correctly" {
    source "$PROJECT_ROOT/setup.sh"
    
    # Override directories
    export APP_SUPPORT_DIR="$TEST_TEMP_DIR/nrBackup"
    export SCRIPTS_DIR="$APP_SUPPORT_DIR/scripts"
    export HELPERS_DIR="$SCRIPTS_DIR/helpers"
    export SCRIPT_DIR="$PROJECT_ROOT"
    
    # Create target directories
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$HELPERS_DIR"
    
    run copy_scripts
    assert_success
    
    # Verify scripts were copied
    assert [ -f "$SCRIPTS_DIR/backup_main.sh" ]
    assert [ -x "$SCRIPTS_DIR/backup_main.sh" ]
    assert [ -f "$HELPERS_DIR/config_parser.sh" ]
    assert [ -f "$HELPERS_DIR/logger.sh" ]
    assert [ -f "$HELPERS_DIR/notification_sender.sh" ]
}

@test "setup: generates valid configuration file" {
    source "$PROJECT_ROOT/setup.sh"
    
    export APP_SUPPORT_DIR="$TEST_TEMP_DIR/nrBackup"
    export CONFIG_FILE="$APP_SUPPORT_DIR/config.json"
    
    mkdir -p "$APP_SUPPORT_DIR"
    
    # Mock user input by overriding read commands
    function read() {
        case "$2" in
            *destination*) echo "/Volumes/TestBackup" ;;
            *choice*) echo "1" ;;
            *detailed*) echo "n" ;;
            *) echo "" ;;
        esac
    }
    export -f read
    
    run generate_config
    assert_success
    
    # Verify config file was created and is valid JSON
    assert [ -f "$CONFIG_FILE" ]
    run jq empty "$CONFIG_FILE"
    assert_success
}

@test "setup: handles missing source scripts gracefully" {
    source "$PROJECT_ROOT/setup.sh"
    
    # Override to point to non-existent directory
    export SCRIPT_DIR="/nonexistent"
    export APP_SUPPORT_DIR="$TEST_TEMP_DIR/nrBackup"
    export SCRIPTS_DIR="$APP_SUPPORT_DIR/scripts"
    
    mkdir -p "$SCRIPTS_DIR"
    
    # Should fail gracefully when source scripts don't exist
    run copy_scripts
    assert_failure
}

setup
teardown