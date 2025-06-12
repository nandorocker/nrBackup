#!/bin/bash

# nrBackup Utility Script
# This script provides various utility functions for managing nrBackup

set -euo pipefail

# Configuration
APP_SUPPORT_DIR="$HOME/Library/Application Support/nrBackup"
CONFIG_FILE="$APP_SUPPORT_DIR/config.json"
LOG_DIR="$HOME/Library/Logs/nrBackup"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.nrbackup.agent.plist"
SCRIPTS_DIR="$APP_SUPPORT_DIR/scripts"
HELPERS_DIR="$SCRIPTS_DIR/helpers"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_color() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

print_info() {
    print_color "$BLUE" "ℹ️  $1"
}

print_success() {
    print_color "$GREEN" "✅ $1"
}

print_warning() {
    print_color "$YELLOW" "⚠️  $1"
}

print_error() {
    print_color "$RED" "❌ $1"
}

# Show usage information
show_usage() {
    echo "nrBackup Utility - Management tool for nrBackup"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show backup system status"
    echo "  config      - Display current configuration"
    echo "  logs        - Show recent log files"
    echo "  test        - Run a test backup"
    echo "  start       - Start the backup agent"
    echo "  stop        - Stop the backup agent"
    echo "  restart     - Restart the backup agent"
    echo "  uninstall   - Remove nrBackup completely"
    echo "  help        - Show this help message"
    echo ""
}

# Check if nrBackup is installed
check_installation() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "nrBackup is not installed. Run setup.sh first."
        exit 1
    fi
    
    if [[ ! -f "$SCRIPTS_DIR/backup_main.sh" ]]; then
        print_error "nrBackup scripts not found. Reinstall may be required."
        exit 1
    fi
}

# Show system status
show_status() {
    print_info "nrBackup System Status"
    echo ""
    
    # Check if agent is loaded
    if launchctl list | grep -q "com.nrbackup.agent"; then
        print_success "Backup agent is loaded and running"
    else
        print_warning "Backup agent is not loaded"
    fi
    
    # Check configuration
    if [[ -f "$CONFIG_FILE" ]]; then
        print_success "Configuration file exists"
        
        # Source config parser
        if [[ -f "$HELPERS_DIR/config_parser.sh" ]]; then
            source "$HELPERS_DIR/config_parser.sh"
            if parse_config "$CONFIG_FILE"; then
                print_success "Configuration is valid"
                
                # Check destination drive
                if [[ -d "$DESTINATION_DRIVE" ]]; then
                    print_success "Destination drive is connected: $DESTINATION_DRIVE"
                else
                    print_warning "Destination drive not found: $DESTINATION_DRIVE"
                fi
            else
                print_error "Configuration is invalid"
            fi
        fi
    else
        print_error "Configuration file not found"
    fi
    
    # Check recent backups
    if [[ -d "$LOG_DIR" ]]; then
        local recent_logs
        recent_logs=$(find "$LOG_DIR" -name "backup_*.log" -type f -mtime -1 | wc -l)
        if [[ "$recent_logs" -gt 0 ]]; then
            print_info "Recent backups: $recent_logs in the last 24 hours"
        else
            print_warning "No recent backup logs found"
        fi
    fi
    
    echo ""
}

# Display configuration
show_config() {
    check_installation
    
    print_info "Current Configuration"
    echo ""
    
    if [[ -f "$HELPERS_DIR/config_parser.sh" ]]; then
        source "$HELPERS_DIR/config_parser.sh"
        if parse_config "$CONFIG_FILE"; then
            display_config
        else
            print_error "Failed to parse configuration"
            exit 1
        fi
    else
        print_error "Configuration parser not found"
        exit 1
    fi
}

# Show recent logs
show_logs() {
    check_installation
    
    print_info "Recent Log Files"
    echo ""
    
    if [[ ! -d "$LOG_DIR" ]]; then
        print_warning "Log directory not found: $LOG_DIR"
        return
    fi
    
    # List recent log files
    local log_files
    log_files=$(find "$LOG_DIR" -name "backup_*.log" -type f | sort -r | head -10)
    
    if [[ -z "$log_files" ]]; then
        print_warning "No log files found"
        return
    fi
    
    echo "Recent backup logs:"
    echo "$log_files" | while IFS= read -r log_file; do
        local file_date
        file_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$log_file" 2>/dev/null || echo "Unknown")
        local file_size
        file_size=$(stat -f "%z" "$log_file" 2>/dev/null || echo "0")
        printf "  %s (%s, %d bytes)\n" "$(basename "$log_file")" "$file_date" "$file_size"
    done
    
    echo ""
    print_info "To view a specific log:"
    print_color "$YELLOW" "  less '$LOG_DIR/backup_YYYY-MM-DD_HH-MM-SS.log'"
    echo ""
    print_info "To view the latest log:"
    local latest_log
    latest_log=$(find "$LOG_DIR" -name "backup_*.log" -type f | sort -r | head -1)
    if [[ -n "$latest_log" ]]; then
        print_color "$YELLOW" "  less '$latest_log'"
    fi
    echo ""
}

# Run test backup
run_test() {
    check_installation
    
    print_info "Running test backup..."
    echo ""
    
    if [[ -f "$SCRIPTS_DIR/backup_main.sh" ]]; then
        print_info "Executing backup script..."
        if "$SCRIPTS_DIR/backup_main.sh"; then
            print_success "Test backup completed successfully"
        else
            print_error "Test backup failed"
            exit 1
        fi
    else
        print_error "Backup script not found"
        exit 1
    fi
}

# Start backup agent
start_agent() {
    check_installation
    
    print_info "Starting backup agent..."
    
    if launchctl list | grep -q "com.nrbackup.agent"; then
        print_warning "Agent is already running"
        return
    fi
    
    if [[ ! -f "$LAUNCHD_PLIST" ]]; then
        print_error "launchd plist not found. Run setup.sh to reinstall."
        exit 1
    fi
    
    if launchctl load "$LAUNCHD_PLIST"; then
        print_success "Backup agent started"
    else
        print_error "Failed to start backup agent"
        exit 1
    fi
}

# Stop backup agent
stop_agent() {
    print_info "Stopping backup agent..."
    
    if ! launchctl list | grep -q "com.nrbackup.agent"; then
        print_warning "Agent is not running"
        return
    fi
    
    if launchctl unload "$LAUNCHD_PLIST" 2>/dev/null; then
        print_success "Backup agent stopped"
    else
        print_error "Failed to stop backup agent"
        exit 1
    fi
}

# Restart backup agent
restart_agent() {
    print_info "Restarting backup agent..."
    stop_agent
    sleep 2
    start_agent
}

# Uninstall nrBackup
uninstall() {
    print_warning "This will completely remove nrBackup from your system."
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_info "Uninstall cancelled"
        return
    fi
    
    print_info "Uninstalling nrBackup..."
    
    # Stop and remove launchd agent
    if launchctl list | grep -q "com.nrbackup.agent"; then
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        print_info "Stopped backup agent"
    fi
    
    if [[ -f "$LAUNCHD_PLIST" ]]; then
        rm -f "$LAUNCHD_PLIST"
        print_info "Removed launchd plist"
    fi
    
    # Remove application files
    if [[ -d "$APP_SUPPORT_DIR" ]]; then
        rm -rf "$APP_SUPPORT_DIR"
        print_info "Removed application files"
    fi
    
    # Ask about log files
    if [[ -d "$LOG_DIR" ]]; then
        read -p "Remove log files? (y/N): " remove_logs
        if [[ "$remove_logs" =~ ^[Yy] ]]; then
            rm -rf "$LOG_DIR"
            print_info "Removed log files"
        else
            print_info "Log files preserved at: $LOG_DIR"
        fi
    fi
    
    print_success "nrBackup has been uninstalled"
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        "status")
            show_status
            ;;
        "config")
            show_config
            ;;
        "logs")
            show_logs
            ;;
        "test")
            run_test
            ;;
        "start")
            start_agent
            ;;
        "stop")
            stop_agent
            ;;
        "restart")
            restart_agent
            ;;
        "uninstall")
            uninstall
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
