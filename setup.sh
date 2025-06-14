#!/bin/bash

# nrBackup Setup Script
# This script sets up the nrBackup utility on macOS

set -euo pipefail

# Parse command line arguments
DEBUG_MODE=false
for arg in "$@"; do
    case $arg in
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--debug] [--help]"
            echo "  --debug    Show detailed setup messages"
            echo "  --help     Show this help message"
            echo ""
            echo "Environment variables:"
            echo "  BACKUP_DEST    Specify backup destination (for non-interactive use)"
            echo "                 Example: BACKUP_DEST=/Volumes/MyDrive ./setup.sh"
            exit 0
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="nrBackup"
APP_SUPPORT_DIR="$HOME/Library/Application Support/nrBackup"
SCRIPTS_DIR="$APP_SUPPORT_DIR/scripts"
HELPERS_DIR="$SCRIPTS_DIR/helpers"
CONFIG_FILE="$APP_SUPPORT_DIR/config.json"
LOG_DIR="$HOME/Library/Logs/nrBackup"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/com.nrbackup.agent.plist"

# Current script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    if [[ "$DEBUG_MODE" == "true" ]]; then
        print_color "$GREEN" "✅ $1"
    fi
}

print_warning() {
    print_color "$YELLOW" "⚠️  $1"
}

print_error() {
    print_color "$RED" "❌ $1"
}

print_debug() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        print_color "$BLUE" "🔍 $1"
    fi
}

# Print banner
print_banner() {
    echo ""
    print_color "$BLUE" "╔══════════════════════════════════════╗"
    print_color "$BLUE" "║            nrBackup Setup            ║"
    print_color "$BLUE" "║     macOS rsync Backup Utility       ║"
    print_color "$BLUE" "╚══════════════════════════════════════╝"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    # Check for terminal-notifier
    if ! command -v terminal-notifier &> /dev/null; then
        missing_tools+=("terminal-notifier")
    fi
    
    # Check for rsync (should be built-in on macOS)
    if ! command -v rsync &> /dev/null; then
        missing_tools+=("rsync")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        print_info "Please install the missing tools using Homebrew:"
        echo ""
        print_color "$YELLOW" "# Install Homebrew if you haven't already:"
        print_color "$YELLOW" '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        print_color "$YELLOW" "# Install required tools:"
        for tool in "${missing_tools[@]}"; do
            if [[ "$tool" != "rsync" ]]; then
                print_color "$YELLOW" "brew install $tool"
            fi
        done
        echo ""
        print_error "Please install the missing tools and run setup again."
        exit 1
    fi
    
    print_debug "All prerequisites are installed"
}

# Create directory structure
create_directories() {
    print_info "Creating directory structure..."
    
    # Create main directories
    mkdir -p "$APP_SUPPORT_DIR"
    mkdir -p "$SCRIPTS_DIR"
    mkdir -p "$HELPERS_DIR"
    mkdir -p "$LOG_DIR"
    
    print_debug "Directory structure created"
}

# Copy scripts
copy_scripts() {
    print_info "Installing scripts..."
    
    # Copy main backup script
    if [[ -f "$SCRIPT_DIR/scripts/backup_main.sh" ]]; then
        cp "$SCRIPT_DIR/scripts/backup_main.sh" "$SCRIPTS_DIR/"
        chmod +x "$SCRIPTS_DIR/backup_main.sh"
        print_debug "Main backup script installed"
    else
        print_error "Main backup script not found in source directory"
        exit 1
    fi
    
    # Copy helper scripts
    local helpers=("config_parser.sh" "logger.sh" "notification_sender.sh")
    for helper in "${helpers[@]}"; do
        if [[ -f "$SCRIPT_DIR/scripts/helpers/$helper" ]]; then
            cp "$SCRIPT_DIR/scripts/helpers/$helper" "$HELPERS_DIR/"
            chmod +x "$HELPERS_DIR/$helper"
            print_debug "Helper script installed: $helper"
        else
            print_error "Helper script not found: $helper"
            exit 1
        fi
    done
}

# Generate default configuration
generate_config() {
    print_info "Generating configuration..."
    
    # Get current user
    local current_user
    current_user=$(whoami)
    
    # Use the previously selected backup destination
    local destination_drive="$BACKUP_DEST"
    
    print_debug "Using backup destination: $destination_drive"
    
    # Ask about schedule type
    echo ""
    print_info "Schedule Configuration"
    echo ""
    print_color "$YELLOW" "Choose backup schedule type:"
    print_color "$YELLOW" "1) Hybrid (recommended) - Backup every 6 hours AND when drive connects"
    print_color "$YELLOW" "2) Interval only - Backup every N hours"
    print_color "$YELLOW" "3) Daily at specific time"
    print_color "$YELLOW" "4) Drive connection only - Backup when drive is connected"
    echo ""
    
    local schedule_choice
    read -p "Enter choice [1]: " schedule_choice
    schedule_choice=${schedule_choice:-1}
    
    local schedule_type="hybrid"
    local interval_hours=6
    local daily_time="02:00"
    
    case "$schedule_choice" in
        1) schedule_type="hybrid" ;;
        2) 
            schedule_type="interval"
            read -p "Enter backup interval in hours [6]: " interval_hours
            interval_hours=${interval_hours:-6}
            ;;
        3) 
            schedule_type="daily_at_time"
            read -p "Enter daily backup time (HH:MM) [02:00]: " daily_time
            daily_time=${daily_time:-"02:00"}
            ;;
        4) schedule_type="on_drive_connect" ;;
        *) 
            print_warning "Invalid choice, using hybrid schedule"
            schedule_type="hybrid"
            ;;
    esac
    
    # Ask about detailed logging
    echo ""
    local detailed_logging="false"
    read -p "Enable detailed logging? (y/N): " enable_detailed
    if [[ "$enable_detailed" =~ ^[Yy] ]]; then
        detailed_logging="true"
    fi
    
    # Create configuration file
    cat > "$CONFIG_FILE" << EOF
{
  "schedule_type": "$schedule_type",
  "interval_hours": $interval_hours,
  "daily_backup_time": "$daily_time",
  "source_paths": [
    "/Users/$current_user"
  ],
  "exclude_paths": [
    "/Users/$current_user/Downloads",
    "/Users/$current_user/Library/Caches",
    "/Users/$current_user/.Trash",
    "/Users/$current_user/.npm",
    "/Users/$current_user/.yarn",
    "**/.DS_Store",
    "**/node_modules",
    "**/.git",
    "**/*.tmp",
    "**/*.temp",
    "**/Thumbs.db",
    "**/.localized"
  ],
  "destination_drive_mount_point": "$destination_drive",
  "detailed_logging": $detailed_logging
}
EOF
    
    print_debug "Configuration file created: $CONFIG_FILE"
}

# Generate launchd plist
generate_launchd_plist() {
    print_info "Creating system configuration..."
    
    # Source the config parser to get schedule settings
    source "$HELPERS_DIR/config_parser.sh"
    if ! parse_config "$CONFIG_FILE"; then
        print_error "Failed to parse configuration for launchd setup"
        exit 1
    fi
    
    # Start building the plist
    cat > "$LAUNCHD_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.nrbackup.agent</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPTS_DIR/backup_main.sh</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/launchd.out</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/launchd.err</string>
EOF
    
    # Add schedule-specific configuration
    case "$SCHEDULE_TYPE" in
        "interval")
            cat >> "$LAUNCHD_PLIST" << EOF
    <key>StartInterval</key>
    <integer>$((INTERVAL_HOURS * 3600))</integer>
EOF
            ;;
        "daily_at_time")
            local hour minute
            hour=$(echo "$DAILY_BACKUP_TIME" | cut -d: -f1)
            minute=$(echo "$DAILY_BACKUP_TIME" | cut -d: -f2)
            cat >> "$LAUNCHD_PLIST" << EOF
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$hour</integer>
        <key>Minute</key>
        <integer>$minute</integer>
    </dict>
EOF
            ;;
        "on_drive_connect")
            cat >> "$LAUNCHD_PLIST" << EOF
    <key>WatchPaths</key>
    <array>
        <string>$DESTINATION_DRIVE</string>
    </array>
EOF
            ;;
        "hybrid")
            local hour minute
            hour=$(echo "$DAILY_BACKUP_TIME" | cut -d: -f1)
            minute=$(echo "$DAILY_BACKUP_TIME" | cut -d: -f2)
            cat >> "$LAUNCHD_PLIST" << EOF
    <key>StartInterval</key>
    <integer>$((INTERVAL_HOURS * 3600))</integer>
    <key>WatchPaths</key>
    <array>
        <string>$DESTINATION_DRIVE</string>
    </array>
EOF
            ;;
    esac
    
    # Close the plist
    cat >> "$LAUNCHD_PLIST" << EOF
</dict>
</plist>
EOF
    
    print_debug "launchd configuration created: $LAUNCHD_PLIST"
}

# Load launchd agent
load_launchd_agent() {
    print_info "Activating backup service..."
    
    # Unload if already loaded
    if launchctl list | grep -q "com.nrbackup.agent"; then
        launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        print_debug "Unloaded existing agent"
    fi
    
    # Load the agent
    if launchctl load "$LAUNCHD_PLIST"; then
        print_debug "launchd agent loaded successfully"
    else
        print_error "Failed to load launchd agent"
        exit 1
    fi
}

# Test the setup
test_setup() {
    print_info "Verifying installation..."
    
    # Test configuration parsing
    source "$HELPERS_DIR/config_parser.sh"
    if parse_config "$CONFIG_FILE"; then
        print_debug "Configuration parsing test passed"
    else
        print_error "Configuration parsing test failed"
        return 1
    fi
    
    # Test notification system
    source "$HELPERS_DIR/logger.sh"
    source "$HELPERS_DIR/notification_sender.sh"
    
    if test_notifications; then
        print_debug "Notification system test passed"
    else
        print_warning "Notification system test failed (non-critical)"
    fi
    
    print_debug "Setup testing completed"
}

# Print final instructions
print_final_instructions() {
    echo ""
    print_color "$GREEN" "╔══════════════════════════════════════╗"
    print_color "$GREEN" "║         Setup Complete! 🎉           ║"
    print_color "$GREEN" "╚══════════════════════════════════════╝"
    echo ""
    
    print_info "nrBackup has been successfully installed and configured!"
    echo ""
    
    print_color "$YELLOW" "📁 Configuration file: $CONFIG_FILE"
    print_color "$YELLOW" "📋 Log directory: $LOG_DIR"
    print_color "$YELLOW" "⚙️  Scripts directory: $SCRIPTS_DIR"
    echo ""
    
    print_info "Next steps:"
    echo ""
    print_color "$YELLOW" "1. Connect your backup drive to: $BACKUP_DEST"
    print_color "$YELLOW" "2. Test manual backup: $SCRIPTS_DIR/backup_main.sh"
    print_color "$YELLOW" "3. Edit config if needed: $CONFIG_FILE"
    print_color "$YELLOW" "4. View logs: ls -la $LOG_DIR"
    echo ""
    
    print_info "The backup agent is now running and will execute according to your schedule."
    print_info "You'll receive macOS notifications when backups complete."
    echo ""
    
    print_color "$BLUE" "For help and documentation, see: README.md"
    echo ""
}

# Cleanup function
cleanup() {
    if [[ $? -ne 0 ]]; then
        print_error "Setup failed. Cleaning up..."
        
        # Remove launchd agent if it was loaded
        if [[ -f "$LAUNCHD_PLIST" ]]; then
            launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
            rm -f "$LAUNCHD_PLIST"
        fi
        
        # Optionally remove created directories
        read -p "Remove created files and directories? (y/N): " cleanup_choice
        if [[ "$cleanup_choice" =~ ^[Yy] ]]; then
            rm -rf "$APP_SUPPORT_DIR"
            rm -rf "$LOG_DIR"
            print_debug "Cleanup completed"
        fi
    fi
}

# Detect and list external drives
detect_external_drives() {
    local drives=()
    local main_disk
    
    # Get the main disk device (e.g., disk0)
    main_disk=$(diskutil info / | grep "Part of Whole:" | awk '{print $4}')
    
    print_debug "Main disk identified as: $main_disk"
    
    # Get all mounted external volumes
    while IFS= read -r line; do
        # Skip header line
        [[ "$line" =~ ^Filesystem ]] && continue
        
        local device=$(echo "$line" | awk '{print $1}')
        local size=$(echo "$line" | awk '{print $2}')
        local mount_point=$(echo "$line" | awk '{for(i=9;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')
        
        # Skip if it's the main disk, system volumes, or not in /Volumes/
        if [[ "$device" != "/dev/${main_disk}"* ]] && \
           [[ "$mount_point" == /Volumes/* ]] && \
           [[ "$mount_point" != "/Volumes/com.apple."* ]]; then
            
            local drive_name=$(basename "$mount_point")
            
            # Convert size to numeric value for sorting (approximate)
            local size_numeric
            if [[ "$size" =~ ([0-9.]+)Ti$ ]]; then
                # For TB, multiply by 1000 to get GB equivalent
                size_numeric=$(awk "BEGIN {printf \"%.0f\", ${BASH_REMATCH[1]} * 1000}")
            elif [[ "$size" =~ ([0-9.]+)Gi$ ]]; then
                size_numeric="${BASH_REMATCH[1]}"
            elif [[ "$size" =~ ([0-9.]+)Mi$ ]]; then
                # For MB, divide by 1000 to get GB equivalent
                size_numeric=$(awk "BEGIN {printf \"%.1f\", ${BASH_REMATCH[1]} / 1000}")
            else
                size_numeric="0"
            fi
            
            drives+=("${size_numeric}|${size}|${drive_name}|${mount_point}")
            print_debug "Found external drive: $drive_name ($size) at $mount_point"
        fi
    done < <(df -h 2>/dev/null)
    
    # Sort by size (largest first)
    printf '%s\n' "${drives[@]}" | sort -t'|' -k1,1nr | cut -d'|' -f2-
}

# Prompt user for backup destination
prompt_backup_destination() {
    # Check if we're in an interactive environment
    if [[ ! -t 0 ]]; then
        print_warning "Non-interactive environment detected."
        print_info "Please specify backup destination manually:"
        print_info "Usage: BACKUP_DEST=/path/to/drive ./setup.sh"
        if [[ -z "${BACKUP_DEST:-}" ]]; then
            print_error "BACKUP_DEST environment variable not set."
            return 1
        fi
        print_debug "Using BACKUP_DEST from environment: $BACKUP_DEST"
        return 0
    fi
    
    print_info "Detecting external drives..."
    
    local external_drives=()
    local drive_output
    drive_output=$(detect_external_drives)
    
    # Convert output to array using a more compatible method
    if [ -n "$drive_output" ]; then
        while IFS= read -r line; do
            external_drives+=("$line")
        done <<< "$drive_output"
    fi
    
    if [ ${#external_drives[@]} -eq 0 ]; then
        print_warning "No external drives detected."
        echo ""
        print_info "Please enter the backup destination path manually:"
        read -r -p "Backup destination: " BACKUP_DEST
        if [[ -z "$BACKUP_DEST" ]]; then
            print_error "No backup destination provided."
            return 1
        fi
        BACKUP_DEST=$(eval echo "$BACKUP_DEST") # Handle ~ expansion
    else
        echo ""
        print_color "$YELLOW" "Available external drives:"
        echo ""
        
        local i=1
        for drive in "${external_drives[@]}"; do
            IFS='|' read -r size name path <<< "$drive"
            printf "  %d) %s (%s) - %s\n" "$i" "$name" "$size" "$path"
            ((i++))
        done
        
        printf "  %d) Other (enter manually)\n" "$i"
        echo ""
        
        local choice
        local attempts=0
        local max_attempts=5
        while true; do
            if ! read -r -p "Select backup destination [1-$i]: " choice; then
                print_error "Failed to read input. Please run in an interactive terminal."
                return 1
            fi
            
            # Check if we're getting empty input repeatedly
            if [[ -z "$choice" ]]; then
                ((attempts++))
                if [[ $attempts -ge $max_attempts ]]; then
                    print_error "Too many empty inputs. Please run the script interactively."
                    print_info "For non-interactive use: BACKUP_DEST=/path/to/drive ./setup.sh"
                    return 1
                fi
                print_warning "Please enter a valid choice (1-$i)."
                continue
            fi
            
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
                if [ "$choice" -eq "$i" ]; then
                    # User chose "Other"
                    echo ""
                    print_info "Enter the backup destination path manually:"
                    read -r -p "Backup destination: " BACKUP_DEST
                    if [[ -z "$BACKUP_DEST" ]]; then
                        print_error "No backup destination provided."
                        return 1
                    fi
                    BACKUP_DEST=$(eval echo "$BACKUP_DEST") # Handle ~ expansion
                else
                    # User chose a detected drive
                    local selected_drive="${external_drives[$((choice-1))]}"
                    IFS='|' read -r size name path <<< "$selected_drive"
                    BACKUP_DEST="$path"
                    print_debug "Selected: $name ($size) at $path"
                fi
                break
            else
                print_warning "Invalid selection. Please choose 1-$i."
                ((attempts++))
                if [[ $attempts -ge $max_attempts ]]; then
                    print_error "Too many invalid attempts. Exiting."
                    return 1
                fi
            fi
        done
    fi
    
    # Validate the chosen destination
    if [ ! -d "$BACKUP_DEST" ]; then
        print_error "Directory '$BACKUP_DEST' does not exist."
        return 1
    fi
    
    if [ ! -w "$BACKUP_DEST" ]; then
        print_error "Directory '$BACKUP_DEST' is not writable."
        return 1
    fi
    
    print_debug "Backup destination set to: $BACKUP_DEST"
    return 0
}

# Main setup function
main() {
    # Set up cleanup on exit
    trap cleanup EXIT
    
    print_banner
    
    # Check if already installed
    if [[ -f "$CONFIG_FILE" ]]; then
        print_warning "nrBackup appears to be already installed."
        read -p "Do you want to reinstall? (y/N): " reinstall
        if [[ ! "$reinstall" =~ ^[Yy] ]]; then
            print_info "Setup cancelled"
            exit 0
        fi
        
        # Unload existing agent
        if [[ -f "$LAUNCHD_PLIST" ]]; then
            launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
        fi
    fi
    
    # Step 1: Select backup destination
    if ! prompt_backup_destination; then
        print_error "Failed to set backup destination."
        exit 1
    fi
    echo ""
    
    check_prerequisites
    create_directories
    copy_scripts
    generate_config
    generate_launchd_plist
    load_launchd_agent
    test_setup
    
    # Show appropriate completion message
    if [[ "$DEBUG_MODE" == "true" ]]; then
        print_final_instructions
    else
        print_color "$GREEN" "✅ Setup completed successfully!"
        echo ""
        print_info "nrBackup has been installed and configured."
        print_info "Backup destination: $BACKUP_DEST"
        print_info "Configuration: $CONFIG_FILE"
        print_info "Logs will be saved to: $LOG_DIR"
        echo ""
        print_info "The backup service is now active and will run according to your schedule."
        if [[ "$DEBUG_MODE" != "true" ]]; then
            echo ""
            print_color "$BLUE" "💡 Run with --debug for detailed setup information"
        fi
        echo ""
    fi
    
    # Disable cleanup on successful completion
    trap - EXIT
}

# Run main function
main "$@"
