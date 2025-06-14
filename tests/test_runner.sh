#!/usr/bin/env bash

# nrBackup Test Runner
# This script runs all tests for the nrBackup project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test configuration
BATS_BIN="$SCRIPT_DIR/framework/bats/bin/bats"
TESTS_DIR="$SCRIPT_DIR/unit"

print_banner() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║            nrBackup Tests            ║${NC}"
    echo -e "${BLUE}║     Bash Automated Testing Suite     ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
}

check_bats() {
    if [[ ! -f "$BATS_BIN" ]]; then
        echo -e "${RED}Error: Bats testing framework not found at $BATS_BIN${NC}"
        echo -e "${YELLOW}Please ensure Bats is installed in tests/framework/bats/${NC}"
        echo ""
        echo "To install Bats as a git submodule:"
        echo "  git submodule add https://github.com/bats-core/bats-core.git tests/framework/bats"
        echo "  git submodule add https://github.com/bats-core/bats-support.git tests/framework/test_helper/bats-support"
        echo "  git submodule add https://github.com/bats-core/bats-assert.git tests/framework/test_helper/bats-assert"
        exit 1
    fi
}

run_test_suite() {
    local test_pattern="$1"
    local description="$2"
    
    echo -e "${BLUE}Running $description...${NC}"
    
    if [[ -f "$test_pattern" ]]; then
        # Single test file
        if "$BATS_BIN" "$test_pattern"; then
            echo -e "${GREEN}✅ $description passed${NC}"
            return 0
        else
            echo -e "${RED}❌ $description failed${NC}"
            return 1
        fi
    elif [[ -d "$test_pattern" ]]; then
        # Directory of tests
        if "$BATS_BIN" "$test_pattern"/*.bats; then
            echo -e "${GREEN}✅ $description passed${NC}"
            return 0
        else
            echo -e "${RED}❌ $description failed${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  No tests found for $description${NC}"
        return 0
    fi
}

run_all_tests() {
    local failed_tests=0
    
    echo -e "${BLUE}Starting test execution...${NC}"
    echo ""
    
    # Run hello world test
    if ! run_test_suite "$TESTS_DIR/hello_world.bats" "Hello World test"; then
        ((failed_tests++))
    fi
    echo ""
    
    # Run helper tests
    if ! run_test_suite "$TESTS_DIR/scripts/helpers" "Helper scripts tests"; then
        ((failed_tests++))
    fi
    echo ""
    
    # Run main script tests
    if ! run_test_suite "$TESTS_DIR/scripts/test_backup_main.bats" "Main backup script tests"; then
        ((failed_tests++))
    fi
    echo ""
    
    # Run setup tests
    if ! run_test_suite "$TESTS_DIR/setup.bats" "Setup script tests"; then
        ((failed_tests++))
    fi
    echo ""
    
    # Print summary
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║          All Tests Passed! 🎉        ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
        return 0
    else
        echo -e "${RED}╔══════════════════════════════════════╗${NC}"
        echo -e "${RED}║       $failed_tests Test Suite(s) Failed! ❌      ║${NC}"
        echo -e "${RED}╚══════════════════════════════════════╝${NC}"
        return 1
    fi
}

run_specific_test() {
    local test_file="$1"
    
    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}Error: Test file not found: $test_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Running specific test: $(basename "$test_file")${NC}"
    "$BATS_BIN" "$test_file"
}

show_help() {
    echo "nrBackup Test Runner"
    echo ""
    echo "Usage: $0 [OPTIONS] [TEST_FILE]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Run tests with verbose output"
    echo "  -a, --all      Run all tests (default)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run all tests"
    echo "  $0 tests/hello_world.bats           # Run specific test file"
    echo "  $0 tests/scripts/helpers/            # Run all tests in directory"
    echo ""
}

main() {
    local verbose=false
    local run_all=true
    local specific_test=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -a|--all)
                run_all=true
                shift
                ;;
            *)
                specific_test="$1"
                run_all=false
                shift
                ;;
        esac
    done
    
    print_banner
    check_bats
    
    if [[ "$run_all" == true ]]; then
        run_all_tests
    else
        run_specific_test "$specific_test"
    fi
}

# Run main function
main "$@"
