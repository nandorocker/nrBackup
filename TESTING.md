# nrBackup Testing Guide

This document provides testing procedures for nrBackup to ensure proper functionality.

## Prerequisites Testing

Before running nrBackup, verify that all prerequisites are installed:

```bash
# Check for jq
which jq || echo "jq not found - install with: brew install jq"

# Check for terminal-notifier
which terminal-notifier || echo "terminal-notifier not found - install with: brew install terminal-notifier"

# Check for rsync (should be built-in)
which rsync || echo "rsync not found"
```

## Installation Testing

### 1. Run Setup Script
```bash
./setup.sh
```

The setup script should:
- Check prerequisites
- Create directory structure
- Copy scripts to system locations
- Generate configuration file
- Create launchd agent
- Load the agent
- Send test notification

### 2. Verify Installation
```bash
# Check if files were created
ls -la ~/Library/Application\ Support/nrBackup/
ls -la ~/Library/Application\ Support/nrBackup/scripts/
ls -la ~/Library/Application\ Support/nrBackup/scripts/helpers/
ls -la ~/Library/LaunchAgents/com.nrbackup.agent.plist
ls -la ~/Library/Logs/nrBackup/

# Check if agent is loaded
launchctl list | grep nrbackup
```

## Configuration Testing

### 1. Validate Configuration
```bash
# Use the utility script to check configuration
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh config
```

### 2. Test Configuration Parser
```bash
# Test configuration parsing directly
cd ~/Library/Application\ Support/nrBackup/scripts/helpers/
source config_parser.sh
parse_config ../config.json && echo "Configuration is valid"
```

## Backup Testing

### 1. Manual Backup Test
```bash
# Run a manual backup (requires backup drive to be connected)
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh test
```

### 2. Dry Run Test
Create a test configuration for dry run:
```bash
# Create a test directory structure
mkdir -p /tmp/nrbackup_test/source
mkdir -p /tmp/nrbackup_test/destination
echo "test file" > /tmp/nrbackup_test/source/test.txt

# Test rsync command manually
rsync -aHX --dry-run --stats /tmp/nrbackup_test/source/ /tmp/nrbackup_test/destination/

# Cleanup
rm -rf /tmp/nrbackup_test
```

## System Status Testing

### 1. Check System Status
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh status
```

### 2. View Logs
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh logs
```

## Agent Management Testing

### 1. Stop Agent
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh stop
```

### 2. Start Agent
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh start
```

### 3. Restart Agent
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh restart
```

## Notification Testing

### 1. Test Notification System
```bash
# Test notifications directly
cd ~/Library/Application\ Support/nrBackup/scripts/helpers/
source logger.sh
source notification_sender.sh
test_notifications
```

### 2. Manual Notification Test
```bash
# Test terminal-notifier directly
terminal-notifier -title "nrBackup Test" -message "Test notification" -sound "Glass"
```

## Error Handling Testing

### 1. Test Missing Destination Drive
```bash
# Temporarily modify config to point to non-existent drive
# Run backup and verify proper error handling
```

### 2. Test Invalid Configuration
```bash
# Create invalid JSON in config file
# Verify proper error reporting
```

## Performance Testing

### 1. Large File Test
```bash
# Create large test files and measure backup performance
dd if=/dev/zero of=/tmp/large_test_file bs=1m count=100
# Add to source path and run backup
```

### 2. Many Files Test
```bash
# Create many small files and test backup performance
mkdir -p /tmp/many_files_test
for i in {1..1000}; do echo "file $i" > /tmp/many_files_test/file_$i.txt; done
# Add to source path and run backup
```

## Cleanup Testing

### 1. Uninstall Test
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh uninstall
```

### 2. Verify Cleanup
```bash
# Check that files were removed
ls ~/Library/Application\ Support/nrBackup/ 2>/dev/null || echo "Application files removed"
ls ~/Library/LaunchAgents/com.nrbackup.agent.plist 2>/dev/null || echo "LaunchAgent removed"
launchctl list | grep nrbackup || echo "Agent unloaded"
```

## Troubleshooting Common Issues

### Issue: Setup fails with permission errors
**Solution**: Ensure you have write permissions to ~/Library directories

### Issue: Agent doesn't start
**Solution**: Check launchd plist syntax and file permissions

### Issue: Backup fails with rsync errors
**Solution**: Check source and destination paths, verify drive is mounted

### Issue: Notifications don't appear
**Solution**: Check terminal-notifier installation and macOS notification settings

### Issue: Configuration parsing fails
**Solution**: Verify JSON syntax and jq installation

## Expected Test Results

### Successful Installation
- All directories created
- Scripts copied and executable
- Configuration file generated
- LaunchAgent loaded
- Test notification sent

### Successful Backup
- Source files copied to destination
- Proper directory structure created
- Log file generated
- Success notification sent
- No error messages in logs

### Successful Management
- Status command shows system state
- Start/stop/restart commands work
- Configuration display is accurate
- Log viewing works correctly

## Automated Testing Script

Create a simple test script:

```bash
#!/bin/bash
# nrBackup Test Suite

echo "Running nrBackup test suite..."

# Test 1: Check prerequisites
echo "Test 1: Prerequisites"
command -v jq >/dev/null 2>&1 && echo "✅ jq found" || echo "❌ jq missing"
command -v terminal-notifier >/dev/null 2>&1 && echo "✅ terminal-notifier found" || echo "❌ terminal-notifier missing"
command -v rsync >/dev/null 2>&1 && echo "✅ rsync found" || echo "❌ rsync missing"

# Test 2: Check installation
echo "Test 2: Installation"
[[ -f ~/Library/Application\ Support/nrBackup/config.json ]] && echo "✅ Config exists" || echo "❌ Config missing"
[[ -f ~/Library/Application\ Support/nrBackup/scripts/backup_main.sh ]] && echo "✅ Main script exists" || echo "❌ Main script missing"

# Test 3: Check agent
echo "Test 3: LaunchAgent"
launchctl list | grep -q nrbackup && echo "✅ Agent loaded" || echo "❌ Agent not loaded"

echo "Test suite complete"
```

This testing guide ensures comprehensive validation of all nrBackup components and functionality.
