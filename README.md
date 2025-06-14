# nrBackup - macOS rsync Backup Utility

A robust, automated backup utility for macOS that uses rsync for incremental backups to external drives.

## Features

- **Automated Scheduling**: Uses macOS launchd for reliable scheduling
- **Incremental Backups**: Only backs up changed files using rsync
- **Flexible Configuration**: JSON-based configuration with sensible defaults
- **Smart Exclusions**: Automatically excludes common unnecessary files
- **Native Notifications**: macOS notifications for backup status
- **Detailed Logging**: Configurable logging levels
- **Multiple Schedule Types**: Time-based, drive-connection, or hybrid scheduling

## Prerequisites

Before installing nrBackup, you need to install these dependencies:

```bash
# Install Homebrew if you haven't already
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install jq terminal-notifier
```

## Installation

1. Clone or download this repository
2. Run the setup script:
   ```bash
   ./setup.sh
   ```
   
   For detailed installation messages, use:
   ```bash
   ./setup.sh --debug
   ```
   
3. Follow the prompts to configure your backup settings

## Configuration

The configuration file is located at `~/Library/Application Support/nrBackup/config.json`.

### Example Configuration

```json
{
  "schedule_type": "hybrid",
  "interval_hours": 6,
  "daily_backup_time": "02:00",
  "source_paths": ["/Users/yourusername"],
  "exclude_paths": [
    "/Users/yourusername/Downloads",
    "/Users/yourusername/Library/Caches",
    "/Users/yourusername/.Trash",
    "**/.DS_Store",
    "**/node_modules",
    "**/.git"
  ],
  "destination_drive_mount_point": "/Volumes/BackupDrive",
  "detailed_logging": false
}
```

### Schedule Types

- **interval**: Backup every N hours
- **daily_at_time**: Backup once daily at specified time
- **on_drive_connect**: Backup when destination drive is connected
- **hybrid**: Combination of interval and drive connection triggers

## Usage

After setup, nrBackup runs automatically according to your schedule. You can also run manual backups and manage the system using the utility script:

```bash
# Run a manual backup
~/Library/Application\ Support/nrBackup/scripts/backup_main.sh

# Or use the utility script for a test backup
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh test
```

## Logs

Backup logs are stored in `~/Library/Logs/nrBackup/` with timestamps.

## Development

### Project Structure

This project is organized into clear directories:

- `scripts/` - Core application scripts
- `docs/` - All project documentation
- `tests/` - Complete testing framework
  - `unit/` - Unit tests using BATS
  - `integration/` - Integration and system tests
  - `config/` - Test configurations
  - `framework/` - Testing framework installation
  - `docs/` - Test documentation and results

For detailed structure information, see `docs/PROJECT_STRUCTURE.md`.

### Running Tests

To run the test suite:

```bash
# Run all tests
./tests/test_runner.sh

# Run specific test file
./tests/test_runner.sh tests/unit/hello_world.bats

# Run integration tests
./tests/integration/auto_test_backup.sh
```

## Management

Use the nrBackup utility script to manage your installation:

```bash
# Show system status
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh status

# Start/stop the backup service
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh start
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh stop
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh restart

# View configuration and logs
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh config
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh logs

# Run a test backup
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh test
```

## Uninstalling

nrBackup provides multiple ways to uninstall:

### Option 1: Using the utility script (recommended)
```bash
~/Library/Application\ Support/nrBackup/scripts/nrbackup-util.sh uninstall
```

### Option 2: Using the standalone uninstall script
```bash
./uninstall.sh
```

For automated uninstallation (skip confirmation):
```bash
./uninstall.sh --force
```

### Option 3: Manual removal
```bash
# Stop the service
launchctl unload ~/Library/LaunchAgents/com.nrbackup.agent.plist

# Remove files
rm -rf ~/Library/Application\ Support/nrBackup
rm -rf ~/Library/Logs/nrBackup
rm ~/Library/LaunchAgents/com.nrbackup.agent.plist
```

**Note:** Uninstalling nrBackup will not delete your backup files. Those remain safely in your backup destination.

## License

MIT License - see LICENSE file for details.
