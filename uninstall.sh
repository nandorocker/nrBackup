#!/bin/bash

# nrBackup Uninstall Script
# This script completely removes nrBackup from your macOS system

set -euo pipefail

# Configuration
APP_SUPPORT_DIR="$HOME/Library/Application Support/nrBackup"
CONFIG_FILE="$APP_SUPPORT_DIR/config.json"
LOG_DIR="$HOME/Library/Logs/nrBackup"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.nrbackup.agent.plist"
SCRIPTS_DIR="$APP_SUPPORT_DIR/scripts"

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

# Print banner
print_banner() {
    echo ""
    print_color "$RED" "╔══════════════════════════════════════╗"
    print_color "$RED" "║          nrBackup Uninstall          ║"
    print_color "$RED" "║     Remove nrBackup from macOS       ║"
    print_color "$RED" "╚══════════════════════════════════════╝"
    echo ""
}

# Check if nrBackup is installed
check_installation() {
    local found_components=()
    
    if [[ -f "$CONFIG_FILE" ]]; then
        found_components+=("Configuration")
    fi
    
    if [[ -d "$SCRIPTS_DIR" ]]; then
        found_components+=("Scripts")
    fi
    
    if [[ -f "$LAUNCHD_PLIST" ]]; then
        found_components+=("LaunchAgent")
    fi
    
    if [[ -d "$LOG_DIR" ]]; then
        found_components+=("Logs")
    fi
    
    if [[ ${#found_components[@]} -eq 0 ]]; then
        print_warning "nrBackup does not appear to be installed on this system."
        return 1
    fi
    
    print_info "Found nrBackup components:"
    for component in "${found_components[@]}"; do
        print_color "$YELLOW" "  • $component"
    done
    echo ""
    
    return 0
}

# Main uninstall function
uninstall_nrbackup() {
    print_warning "This will completely remove nrBackup from your system."
    print_warning "This action cannot be undone."
    echo ""
    
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "Uninstall cancelled"
        exit 0
    fi
    
    echo ""
    print_info "Uninstalling nrBackup..."
    echo ""
    
    # Stop and remove launchd agent
    if launchctl list | grep -q "com.nrbackup.agent" 2>/dev/null; then
        print_info "Stopping backup agent..."
        if launchctl unload "$LAUNCHD_PLIST" 2>/dev/null; then
            print_success "Backup agent stopped"
        else
            print_warning "Could not stop backup agent (it may not be running)"
        fi
    else
        print_info "Backup agent is not running"
    fi
    
    # Remove launchd plist
    if [[ -f "$LAUNCHD_PLIST" ]]; then
        print_info "Removing LaunchAgent configuration..."
        if rm -f "$LAUNCHD_PLIST"; then
            print_success "LaunchAgent configuration removed"
        else
            print_error "Failed to remove LaunchAgent configuration"
        fi
    fi
    
    # Remove application files
    if [[ -d "$APP_SUPPORT_DIR" ]]; then
        print_info "Removing application files..."
        if rm -rf "$APP_SUPPORT_DIR"; then
            print_success "Application files removed"
        else
            print_error "Failed to remove application files"
        fi
    fi
    
    # Handle log files
    if [[ -d "$LOG_DIR" ]]; then
        echo ""
        print_warning "Log files found at: $LOG_DIR"
        read -p "Remove log files? (y/N): " remove_logs
        
        if [[ "$remove_logs" =~ ^[Yy] ]]; then
            if rm -rf "$LOG_DIR"; then
                print_success "Log files removed"
            else
                print_error "Failed to remove log files"
            fi
        else
            print_info "Log files preserved at: $LOG_DIR"
        fi
    fi
    
    echo ""
    print_success "nrBackup has been completely uninstalled from your system"
    echo ""
    print_info "Note: Your backup files remain untouched in their destination location."
    print_info "If you want to remove backup files, you'll need to do that manually."
    echo ""
}

# Show help
show_help() {
    echo "nrBackup Uninstall Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo "  --force       Skip confirmation prompt (use with caution)"
    echo ""
    echo "This script will remove:"
    echo "  • nrBackup configuration files"
    echo "  • nrBackup scripts and utilities"
    echo "  • LaunchAgent (automatic backup scheduling)"
    echo "  • Log files (optional)"
    echo ""
    echo "Your actual backup files will NOT be deleted."
    echo ""
}

# Parse command line arguments
FORCE_UNINSTALL=false
for arg in "$@"; do
    case $arg in
        --force)
            FORCE_UNINSTALL=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown argument: $arg"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_banner
    
    # Check if nrBackup is installed
    if ! check_installation; then
        exit 0
    fi
    
    # Force uninstall mode (skip confirmation)
    if [[ "$FORCE_UNINSTALL" == "true" ]]; then
        print_warning "Force uninstall mode enabled - skipping confirmation"
        echo ""
        
        # Set a dummy confirmation to proceed
        confirm="yes"
        
        print_info "Uninstalling nrBackup..."
        echo ""
        
        # Stop and remove launchd agent
        if launchctl list | grep -q "com.nrbackup.agent" 2>/dev/null; then
            print_info "Stopping backup agent..."
            launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
            print_success "Backup agent stopped"
        fi
        
        # Remove launchd plist
        if [[ -f "$LAUNCHD_PLIST" ]]; then
            rm -f "$LAUNCHD_PLIST"
            print_success "LaunchAgent configuration removed"
        fi
        
        # Remove application files
        if [[ -d "$APP_SUPPORT_DIR" ]]; then
            rm -rf "$APP_SUPPORT_DIR"
            print_success "Application files removed"
        fi
        
        # Remove log files in force mode
        if [[ -d "$LOG_DIR" ]]; then
            rm -rf "$LOG_DIR"
            print_success "Log files removed"
        fi
        
        echo ""
        print_success "nrBackup has been completely uninstalled"
    else
        # Interactive uninstall
        uninstall_nrbackup
    fi
}

# Run main function
main "$@"
