# Product Requirements Document: macOS rsync Backup Utility

Document Version: 1.0

Date: June 12, 2025

Author: Gemini

## 1. Introduction

### 1.1. Purpose

This Product Requirements Document (PRD) outlines the specifications for a personal, automated macOS backup utility. This "mini-app" will leverage the `rsync` command-line tool to perform incremental backups to an external drive, providing configurable options for source inclusion, folder exclusion, scheduling, logging, and user notifications. The primary goal is to provide a robust, flexible, and easy-to-manage backup solution for macOS users, without requiring complex manual intervention after initial setup.

### 1.2. Scope

This document details the requirements for the initial version of the backup utility. It covers automated execution via `launchd`, JSON-based configuration, `rsync` operations, basic logging, and macOS native notifications. Future enhancements (e.g., a dedicated GUI, snapshotting) are identified but are explicitly out of scope for this version.

### 1.3. Goals

- **Reliability:** Ensure consistent and successful data backups based on user configuration.
    
- **Automation:** Provide a truly "set-and-forget" backup experience once configured.
    
- **Configurability:** Empower the user to define what, where, and when to back up without editing complex scripts.
    
- **Transparency:** Inform the user about backup status (success/failure) and provide detailed logs when needed.
    
- **Performance Awareness:** Minimize the impact on system performance during backup operations.
    
- **Modularity:** Design the solution in a way that facilitates future expansion and the addition of a graphical user interface (GUI).
    

## 2. User Stories

To understand the system from a user's perspective, consider the following user stories:

- **As a macOS user, I want my data to be backed up automatically** so I don't have to remember to do it manually.
    
- **As a macOS user, I want to decide which drives and folders get backed up** so I can control what data is protected.
    
- **As a macOS user, I want to exclude specific sensitive or unnecessary folders** (e.g., `Downloads`, `node_modules`) from my backups to save space and time.
    
- **As a macOS user, I want to define how often my backups occur** (e.g., daily, every few hours, when my backup drive is connected) to suit my data change frequency.
    
- **As a macOS user, I want to be notified when a backup finishes** so I know if it was successful or if there were any issues.
    
- **As a macOS user, I want to see a simple summary of my backups** but also have the option to view a detailed log for troubleshooting.
    
- **As a macOS user, I want my backup settings to be easily viewable and transferable** (e.g., to a new Mac) so I can maintain my backup strategy.
    
- **As a macOS user, I want the backup process to run in the background without significantly slowing down my computer** so I can continue working uninterrupted.
    
- **As a macOS user, I want the backup destination on my external drive to be organized** (e.g., by computer name) for clarity.
    

## 3. Requirements

### 3.1. Functional Requirements

#### 3.1.1. Automated Backup Execution

- **FR1.1: Scheduling Mechanism:** The utility shall employ `launchd` `.plist` files for robust, system-level task scheduling.
    
    - **FR1.1.1: Time-Based Scheduling:** The configuration shall support scheduling backups at fixed time intervals (e.g., every 4 hours, daily, weekly) or at specific times of day (e.g., daily at 3:00 AM).
        
    - **FR1.1.2: External Drive Connection Trigger:** The utility shall also trigger a backup when the designated external backup drive is detected as connected/mounted, in addition to any timed schedules. This provides a hybrid scheduling approach.
        
- **FR1.2: Backup Logic (rsync):** The core backup operation shall use the `rsync` command-line tool.
    
    - **FR1.2.1: Incremental Backups:** `rsync` shall be configured to perform incremental backups, transferring only new or changed files based on modification times and file sizes (default `rsync` behavior).
        
    - **FR1.2.2: Comprehensive Copy:** `rsync` shall be configured to preserve permissions, ownership, timestamps, symbolic links, and extended attributes where possible (e.g., using `rsync -aHX`).
        
- **FR1.3: Source Selection:**
    
    - **FR1.3.1: Configurable Sources:** The user shall specify one or more source mount points (e.g., `/Users/yourusername`, `/Volumes/MyInternalSSDPartition`) within the configuration.
        
    - **FR1.3.2: Path Validation:** The utility should perform a basic check to ensure specified source paths exist before attempting a backup.
        
- **FR1.4: Exclusion Handling:**
    
    - **FR1.4.1: Configurable Exclusions:** The user shall specify a list of **exact folder paths** (e.g., `/Users/yourusername/Downloads`, `/Users/yourusername/Library/Caches`, `/path/to/project/node_modules`) to be excluded from _all_ source backups.
        
    - **FR1.4.2: rsync Exclusion Syntax:** The utility shall translate these paths into appropriate `rsync` `--exclude` arguments.
        
- **FR1.5: Destination Management:**
    
    - **FR1.5.1: Configurable Destination Drive:** The user shall specify the mount point of the external destination drive (e.g., `/Volumes/MyBackupDrive`).
        
    - **FR1.5.2: Standardized Backup Path:** On the destination drive, backups shall be stored in a consistent, standardized directory structure: `/Volumes/YourBackupDrive/Backups/[Computer Name]/`, where `[Computer Name]` is automatically determined (e.g., via `hostname`). The utility shall create this path if it does not exist.
        
    - **FR1.5.3: No Snapshots:** The initial version will explicitly _not_ implement `rsync` snapshotting (`--link-dest`) or versioning beyond the direct mirroring provided by `rsync`.
        

#### 3.1.2. Configuration Management

- **FR2.1: JSON Configuration File:** All user-configurable settings shall be stored in a single, well-formatted, human-readable JSON file.
    
- **FR2.2: Configuration File Location:** The default location for the configuration file shall be `~/Library/Application Support/YourBackupApp/config.json`.
    
- **FR2.3: Configurable Parameters:** The JSON file shall support the following parameters:
    
    - `"schedule_type"`: (e.g., `"interval"`, `"daily_at_time"`, `"on_drive_connect"`, `"hybrid"`)
        
    - `"interval_hours"`: (Integer, if `schedule_type` is `"interval"` or `"hybrid"`)
        
    - `"daily_backup_time"`: (String, e.g., `"03:00"`, if `schedule_type` is `"daily_at_time"` or `"hybrid"`)
        
    - `"source_paths"`: (Array of strings, e.g., `["/Users/yourusername", "/Volumes/DataDisk"]`)
        
    - `"exclude_paths"`: (Array of strings, e.g., `["/Users/yourusername/Downloads", "/Users/yourusername/Library/Caches"]`)
        
    - `"destination_drive_mount_point"`: (String, e.g., `"/Volumes/MyExternalBackup"`)
        
    - `"detailed_logging"`: (Boolean, `true` for detailed, `false` for basic)
        
- **FR2.4: Default Configuration:** The utility shall provide a mechanism to generate a default `config.json` if one is not found.
    

#### 3.1.3. User Interaction & Feedback

- **FR3.1: Real-time Progress (Terminal Output):**
    
    - **FR3.1.1: Default Verbosity:** When the main backup script is executed directly from a terminal, it shall output `rsync`'s verbose progress (e.g., `rsync -P --stats`) directly to `stdout` so the user can monitor file transfers, progress percentage, and summary statistics.
        
    - **FR3.1.2: Suppressed for `launchd`:** When run by `launchd` in the background, this verbose output will be redirected to the detailed log file (if enabled) or suppressed to `null` to avoid cluttering system logs.
        
- **FR3.2: Native macOS Notifications:**
    
    - **FR3.2.1: Completion Notification:** Upon the completion of _every_ backup job (regardless of success or failure), a macOS native notification shall be displayed via `terminal-notifier` (or a similar tool).
        
    - **FR3.2.2: Success Notification:** For successful backups, the notification shall clearly state "Backup Completed Successfully" along with the backup duration and destination.
        
    - **FR3.2.3: Failure Notification:** For failed backups, the notification shall clearly state "Backup Failed" and include a brief error message or reason (e.g., "Destination drive not found," "rsync error code X").
        
    - **FR3.2.4: Tooling Prerequisite:** The utility shall inform the user (e.g., via initial setup instructions or a log message) if `terminal-notifier` is required and not found.
        

#### 3.1.4. Logging

- **FR4.1: Log Storage Location:** All log files shall be stored in a dedicated, timestamped directory within `~/Library/Logs/YourBackupApp/`. Each backup run will create a new log file or append to a daily log file (TBD in design, but timestamped entry is key).
    
- **FR4.2: Log File Naming:** Log files shall be named in a consistent, chronological manner (e.g., `backup_YYYY-MM-DD_HH-MM-SS.log`).
    
- **FR4.3: Log Content - Basic Level:** When `detailed_logging` is `false`, the log entry shall include:
    
    - Timestamp of backup start and end.
        
    - Overall status (Success/Failure).
        
    - Destination drive used.
        
    - Summary statistics from `rsync` (e.g., total files transferred, total data transferred, transfer speed, elapsed time).
        
    - Any critical errors.
        
- **FR4.4: Log Content - Detailed Level:** When `detailed_logging` is `true`, the log file shall include:
    
    - All content from the basic log.
        
    - The complete, verbose output of the `rsync` command, capturing every file transferred and `rsync` diagnostics.
        
    - Full command executed, including all `rsync` options.
        
- **FR4.5: Error Logging:** Any errors encountered by the utility scripts (e.g., configuration parsing errors, `launchd` setup issues, `rsync` non-zero exit codes) shall be logged.
    

### 3.2. Non-Functional Requirements

#### 3.2.1. Performance

- **NFR1.1: Minimal System Impact:** Backup operations shall utilize `nice` to lower the CPU priority of `rsync` and associated processes, minimizing impact on foreground interactive applications.
    
- **NFR1.2: Efficiency:** `rsync`'s incremental nature shall ensure that subsequent backups (after the initial full backup) complete quickly by only transferring changes.
    

#### 3.2.2. Reliability & Error Handling

- **NFR2.1: Robustness:** The utility shall be robust against common issues such as a disconnected destination drive or non-existent source paths.
    
- **NFR2.2: Error Reporting:** All significant errors during backup execution shall be captured, logged, and trigger a failure notification.
    
- **NFR2.3: Atomic Operations (rsync):** `rsync` itself handles atomicity reasonably well for individual file transfers. The overall backup job is not strictly atomic (e.g., if power loss occurs mid-backup, the destination might be incomplete but not corrupted).
    

#### 3.2.3. Security

- **NFR3.1: Permissions:** The utility's scripts and configuration files shall adhere to appropriate macOS file permissions to prevent unauthorized modification.
    
- **NFR3.2: Data Integrity:** `rsync`'s checksumming (when applicable, or based on modification times) helps ensure data integrity during transfer.
    

#### 3.2.4. Maintainability & Modularity

- **NFR4.1: Modular Design:** The solution shall be structured with distinct shell scripts or functions for configuration parsing, `rsync` execution, logging, and notification, promoting code reusability and ease of maintenance.
    
- **NFR4.2: Readability:** Scripts shall be well-commented and follow best practices for shell scripting.
    
- **NFR4.3: Configurability:** Changes to backup parameters shall be achievable solely by editing the JSON configuration file, without modifying the core backup scripts.
    

#### 3.2.5. Usability (for configuration)

- **NFR5.1: Human-Readable Configuration:** The JSON configuration file format shall be easy for a human to read and manually edit using a text editor.
    
- **NFR5.2: Clear Instructions:** Comprehensive instructions shall be provided for initial setup, configuration, and `launchd` integration.
    

## 4. High-Level Technical Design Considerations

### 4.1. Architecture

The "mini-app" will primarily be a collection of shell scripts orchestrated by `launchd`.

- **`launchd`:** Will serve as the primary scheduler and orchestrator, executing the main backup script at specified intervals or in response to events (like drive connection).
    
- **Main Backup Script (`backup_app.sh`):** This central script will:
    
    - Parse the JSON configuration.
        
    - Determine the current `[Computer Name]`.
        
    - Validate source and destination paths.
        
    - Construct the `rsync` command, including `nice` and all necessary options (`-aHX`, `--exclude`, etc.).
        
    - Execute the `rsync` command.
        
    - Capture `rsync`'s output and exit status.
        
    - Invoke helper functions/scripts for logging and notifications.
        
- **Helper Scripts/Functions:**
    
    - `read_config.sh` (or function within main script): Reads and parses `config.json` (potentially using `jq`).
        
    - `send_notification.sh` (or function): Wrapper around `terminal-notifier`.
        
    - `write_log.sh` (or function): Handles appending to log files, based on `detailed_logging` flag.
        

### 4.2. Key Technologies

- **`bash` (Shell Scripting):** The primary language for the utility.
    
- **`launchd`:** macOS native service management framework for scheduling.
    
- **`rsync`:** The core utility for file synchronization and backup.
    
- **`jq` (JSON processor):** Highly recommended for parsing JSON configuration within shell scripts. This will need to be a prerequisite for the user to install (e.g., via Homebrew).
    
- **`terminal-notifier`:** Command-line tool for sending macOS user notifications. Also a prerequisite.
    
- **`nice`:** For process priority management.
    

### 4.3. File System Structure (Proposed)

```
~/Library/Application Support/YourBackupApp/
├── config.json                 # User-configurable settings
└── scripts/
    ├── backup_app.sh           # Main orchestration script
    └── setup_launchd.sh        # Helper for initial launchd setup
    └── helpers/
        ├── send_notification.sh # Helper script for sending notifications
        └── write_log.sh         # Helper script for writing log entries
        # (Alternatively, helper functions could be in backup_app.sh directly)

~/Library/LaunchAgents/
└── com.yourusername.backupapp.plist # launchd plist file

~/Library/Logs/YourBackupApp/
├── backup_2025-06-12_10-00-00.log # Example detailed log
└── backup_2025-06-12_14-30-00.log # Example basic log
```

### 4.4. Error Handling Strategy

- Shell scripts will check `rsync`'s exit code (`$?`). A non-zero exit code indicates an error.
    
- Basic checks for existence of source/destination paths before `rsync` execution.
    
- `try-catch` equivalents in shell (e.g., `set -e`, `trap ERR`) to catch and report script-level errors.
    
- All errors will trigger a failure notification and be written to the log.
    

## 5. Future Enhancements (Roadmap)

These features are out of scope for the initial version but represent potential areas for future development:

- **Graphical User Interface (GUI):** A native macOS application or web-based interface for easier configuration, monitoring, and manual backup initiation.
    
- **Snapshotting/Versioning:** Implement `rsync`'s `--link-dest` option to create time-stamped snapshots on the destination, allowing recovery of older file versions.
    
- **Cloud Backup Integration:** Extend functionality to support cloud storage services (e.g., S3, Backblaze B2) using tools like `rclone`.
    
- **More Sophisticated Drive Detection:** Handle multiple potential backup drives, auto-select based on certain criteria, or prompt the user.
    
- **Detailed Progress Bar/Window:** A dedicated UI element to show `rsync` progress without needing to keep a terminal open.
    
- **Pre/Post-Backup Hooks:** Allow users to define custom scripts to run before or after a backup (e.g., unmount a drive, run a database dump).
    
- **Exclusion Patterns:** Support for wildcard patterns (e.g., `*.tmp`, `**/node_modules`) for more flexible exclusions.
    
- **Initial Setup Assistant:** A script or simple UI to guide the user through the initial configuration and `launchd` setup.
    

## 6. Out of Scope

The following features and functionalities are explicitly out of scope for this initial version:

- Full GUI application.
    
- Any form of data encryption on the destination.
    
- Remote backups (e.g., SSH `rsync` to another machine, cloud storage).
    
- Automated cleanup/pruning of old backups.
    
- Complex versioning or snapshot management beyond `rsync`'s basic overwrite behavior.
    
- Pre-built binary distribution of `jq` or `terminal-notifier`. Users will be expected to install these prerequisites.
    
- Real-time file system monitoring (beyond `launchd`'s basic drive connection trigger).
    
- Time Machine integration or replacement. This is a separate, independent `rsync`-based solution.
    

## 7. Success Metrics

The success of this project will be measured by the following criteria:

- **Functional Accuracy:** The utility successfully performs backups according to the configured sources, exclusions, and destinations.
    
- **Reliable Automation:** `launchd` successfully triggers backups as scheduled and upon drive connection.
    
- **Clear Feedback:** Users consistently receive clear notifications (success/failure) at the end of each backup.
    
- **Informative Logging:** Logs accurately record backup events and provide both basic and detailed output as configured.
    
- **Ease of Configuration:** The JSON configuration file is intuitive enough for a user to understand and modify after initial setup.
    
- **Minimal User Complaint:** Low incidence of issues related to performance impact or backup failures that are not clearly reported.