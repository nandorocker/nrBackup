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
    
    # Verify parsed values
    assert_equal "$SCHEDULE_TYPE" "interval"
    assert_equal "$INTERVAL_HOURS" "6"
    assert_equal "$DAILY_BACKUP_TIME" "02:00"
    assert_equal "$DESTINATION_DRIVE" "/Volumes/TestBackup"
    assert_equal "$DETAILED_LOGGING" "false"
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
    
    # Override mock jq to simulate invalid JSON
    cat > "$MOCK_JQ" << 'EOF'
#!/bin/bash
if [[ "$1" == "empty" ]]; then
    exit 1  # Simulate invalid JSON
fi
EOF
    chmod +x "$MOCK_JQ"
    
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
    assert_equal "${#SOURCE_PATHS[@]}" "1"
    assert_equal "${SOURCE_PATHS[0]}" "/Users/testuser"
}

@test "config_parser: parses exclude paths array" {
    local test_config="$TEST_CONFIG_DIR/test_config.json"
    create_test_config "$test_config"
    
    source "$PROJECT_ROOT/scripts/helpers/config_parser.sh"
    parse_config "$test_config"
    
    # Check that EXCLUDE_PATHS array is populated
    assert_equal "${#EXCLUDE_PATHS[@]}" "3"
    assert_equal "${EXCLUDE_PATHS[0]}" "Downloads"
    assert_equal "${EXCLUDE_PATHS[1]}" ".Trash"
    assert_equal "${EXCLUDE_PATHS[2]}" "**/.DS_Store"
}