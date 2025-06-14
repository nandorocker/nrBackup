#!/usr/bin/env bats

load '../../test_helper.bash'

@test "config_parser: loads and parses valid configuration" {
    # Create test config
    local test_config="$TEST_CONFIG_DIR/test_config.json"
    create_test_config "$test_config"
    
    # Source the config parser
    source "$PROJECT_ROOT/scripts/helpers/config_parser.sh"
    
    # Test parsing
    run parse_config "$test_config"
    assert_success
    
    # Verify parsed values (these should be set as global variables)
    # Note: We can't assert on the variables directly in the run context,
    # so we'll parse again outside of run
    parse_config "$test_config"
    [[ "$SCHEDULE_TYPE" == "interval" ]]
    [[ "$INTERVAL_HOURS" == "6" ]]
    [[ "$DAILY_BACKUP_TIME" == "02:00" ]]
    [[ "$DESTINATION_DRIVE" == "/Volumes/TestBackup" ]]
    [[ "$DETAILED_LOGGING" == "false" ]]
}

@test "config_parser: handles missing configuration file" {
    source "$PROJECT_ROOT/scripts/helpers/config_parser.sh"
    
    run parse_config "/nonexistent/config.json"
    assert_failure
    assert_output --partial "Configuration file not found"
}

@test "config_parser: handles invalid JSON" {
    local test_config="$TEST_CONFIG_DIR/invalid_config.json"
    create_invalid_config "$test_config"
    
    source "$PROJECT_ROOT/scripts/helpers/config_parser.sh"
    
    run parse_config "$test_config"
    assert_failure
    assert_output --partial "Invalid JSON"
}

@test "config_parser: parses source paths array" {
    local test_config="$TEST_CONFIG_DIR/test_config.json"
    create_test_config "$test_config"
    
    source "$PROJECT_ROOT/scripts/helpers/config_parser.sh"
    parse_config "$test_config"
    
    # Check that SOURCE_PATHS array is populated
    [[ "${#SOURCE_PATHS[@]}" -eq 1 ]]
    [[ "${SOURCE_PATHS[0]}" == "$TEST_TEMP_DIR/testuser" ]]
}

@test "config_parser: parses exclude paths array" {
    local test_config="$TEST_CONFIG_DIR/test_config.json"
    create_test_config "$test_config"
    
    source "$PROJECT_ROOT/scripts/helpers/config_parser.sh"
    parse_config "$test_config"
    
    # Check that EXCLUDE_PATHS array is populated
    [[ "${#EXCLUDE_PATHS[@]}" -eq 3 ]]
    [[ "${EXCLUDE_PATHS[0]}" == "Downloads" ]]
    [[ "${EXCLUDE_PATHS[1]}" == ".Trash" ]]
    [[ "${EXCLUDE_PATHS[2]}" == "**/.DS_Store" ]]
}