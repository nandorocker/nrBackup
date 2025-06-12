# nrBackup Project Structure

This document outlines the complete structure of the nrBackup utility.

## Project Files

```
nrBackup/
├── README.md                           # Main documentation
├── LICENSE                             # MIT License
├── prd.md                             # Product Requirements Document
├── PROJECT_STRUCTURE.md               # This file
├── config.sample.json                 # Sample configuration file
├── setup.sh                          # Installation script (executable)
└── scripts/
    ├── backup_main.sh                 # Main backup orchestration script (executable)
    ├── nrbackup-util.sh              # Utility management script (executable)
    └── helpers/
        ├── config_parser.sh           # JSON configuration parser (executable)
        ├── logger.sh                  # Logging functionality (executable)
        └── notification_sender.sh     # macOS notification handler (executable)
```

## Installation Structure (After Setup)

When installed, nrBackup creates the following structure on the user's system:

```
~/Library/Application Support/nrBackup/
├── config.json                        # User configuration
└── scripts/
    ├── backup_main.sh                 # Main backup script
    ├── nrbackup-util.sh              # Utility script
    └── helpers/
        ├── config_parser.sh           # Configuration parser
        ├── logger.sh                  # Logging helper
        └── notification_sender.sh     # Notification helper

~/Library/LaunchAgents/
└── com.nrbackup.agent.plist          # launchd configuration

~/Library/Logs/nrBackup/
└── backup_YYYY-MM-DD_HH-MM-SS.log    # Timestamped log files
```

## Core Components

### 1. Setup Script (`setup.sh`)
- **Purpose**: One-time installation and configuration
- **Features**:
  - Checks prerequisites (jq, terminal-notifier)
  - Creates directory structure
  - Copies scripts to system locations
  - Generates user configuration
  - Creates and loads launchd agent
  - Tests installation

### 2. Main Backup Script (`scripts/backup_main.sh`)
- **Purpose**: Core backup orchestration
- **Features**:
  - Parses configuration
  - Validates environment and paths
  - Builds and executes rsync commands
  - Handles logging and notifications
  - Error handling and recovery

### 3. Configuration Parser (`scripts/helpers/config_parser.sh`)
- **Purpose**: JSON configuration management
- **Features**:
  - Parses and validates JSON configuration
  - Expands environment variables
  - Generates default configurations
  - Configuration validation

### 4. Logger (`scripts/helpers/logger.sh`)
- **Purpose**: Comprehensive logging system
- **Features**:
  - Timestamped log entries
  - Multiple log levels (INFO, WARNING, ERROR, DEBUG)
  - Colored terminal output
  - Log rotation
  - System information logging

### 5. Notification Sender (`scripts/helpers/notification_sender.sh`)
- **Purpose**: macOS native notifications
- **Features**:
  - Success/failure notifications
  - Fallback notification methods
  - Notification preferences
  - Interactive notifications with actions

### 6. Utility Script (`scripts/nrbackup-util.sh`)
- **Purpose**: System management and monitoring
- **Features**:
  - Status checking
  - Configuration display
  - Log file management
  - Agent start/stop/restart
  - Test backup execution
  - Complete uninstallation

## Configuration

### Schedule Types
- **interval**: Backup every N hours
- **daily_at_time**: Backup once daily at specified time
- **on_drive_connect**: Backup when destination drive is connected
- **hybrid**: Combination of interval and drive connection triggers

### Default Exclusions
- `.DS_Store` (macOS metadata)
- `node_modules/` (Node.js dependencies)
- `.git/` (Git repositories)
- `Library/Caches/` (System caches)
- `Downloads/` (Downloads folder)
- `.Trash/` (Trash folder)
- `*.tmp` and `*.temp` (Temporary files)
- `.npm/` and `.yarn/` (Package manager caches)

## Dependencies

### Required
- **jq**: JSON processor for configuration parsing
- **terminal-notifier**: macOS notification tool
- **rsync**: File synchronization (built into macOS)

### Built-in macOS Tools
- **launchd**: System service management
- **bash**: Shell scripting environment
- **osascript**: AppleScript execution (fallback notifications)

## Usage Workflow

1. **Installation**: Run `./setup.sh`
2. **Configuration**: Edit `~/Library/Application Support/nrBackup/config.json`
3. **Monitoring**: Use `nrbackup-util.sh status` to check system
4. **Testing**: Use `nrbackup-util.sh test` for manual backup
5. **Management**: Use various `nrbackup-util.sh` commands

## Security Considerations

- Scripts use `set -euo pipefail` for robust error handling
- File permissions are properly set during installation
- Configuration files are stored in user-specific directories
- No elevated privileges required for operation
- rsync preserves file permissions and ownership

## Future Enhancements

As outlined in the PRD, potential future features include:
- Graphical user interface
- Snapshot/versioning support
- Cloud backup integration
- More sophisticated drive detection
- Pre/post-backup hooks
- Exclusion pattern wildcards
