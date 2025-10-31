# Linux Recycle Bin System
## Author
Guilherme Gomes, 125493
Tomás Xavier, 125438
## Description
Project for SO in Engenharia Informática at Universidade de Aveiro to create a Linux shell-based recycle bin for recovering deleted files via command-line interface.
## Installation
To set up our Linux Recycle Bin system, download or copy the recycle_bin.sh script to your preferred directory and make it executable using chmod +x recycle_bin.sh.

When the script is executed for the first time, it automatically creates the required directory structure under ~/.recycle_bin/, including the files/ subdirectory, the metadata.db database, the config file with default settings, and the recyclebin.log log file.

## Usage

 1. Make the script executable (if not already):

		```bash
		chmod +x recycle_bin.sh
		```

 2. Run a command:

		```bash
		./recycle_bin.sh [command] [options]
		```

### Common commands

- delete < path >
	- Move a file or directory to the recycle bin.
	- Example: `./recycle_bin.sh delete myfile.txt` or `./recycle_bin.sh delete myfolder/`

- list [--detailed]
	- List items currently in the recycle bin. Use `--detailed` to show size, permissions and owner.
	- Example: `./recycle_bin.sh list --detailed`

- restore <ID|name> [--overwrite]
	- Restore an item to its original path. Supply the item ID (from `list`) or a name.
	- Example: `./recycle_bin.sh restore 1696234567_abc123`

- search < pattern > [--ignore-case]
	- Find items by name or pattern (wildcards supported).
	- Example: `./recycle_bin.sh search "*.pdf" --ignore-case`

- empty [--force]
	- Permanently remove all items (or selected IDs) from the recycle bin. Use `--force` to skip confirmation.
	- Example: `./recycle_bin.sh empty --force`

- preview <ID|name> [--lines N]
	- Show a short preview of a stored file (text) or summary for binaries.
	- Example: `./recycle_bin.sh preview myfile.txt`

- config_bin_size < KB >
	- Set the maximum allowed recycle bin size in kilobytes.
	- Example: `./recycle_bin.sh config_bin_size 10240` (10 MB)

- config_bin_time < days >
	- Set retention time (in days) for automatic cleanup.
	- Example: `./recycle_bin.sh config_bin_time 7`

- help
	- Show the built-in usage guide and all available commands.
	- Example: `./recycle_bin.sh help`

## Features

### Automatic Recycle Bin Initialization:
On first execution, the script automatically creates the full recycle bin structure (~/.recycle_bin/), including the files/ directory, metadata.db, config, and recyclebin.log files.

### File and Directory Deletion:
Supports deleting both files and directories safely by moving them to the recycle bin instead of permanently removing them.

### Metadata Tracking:
Every deleted item is logged in metadata.db with detailed attributes such as unique ID, original name, original path, deletion date, file size, type, permissions, and owner.

### Restoration System:
Allows users to restore deleted items to their original location, handling name conflicts with overwrite, rename, or cancel options.

### Formatted Listing:
Displays all recycled items in a structured table, with an optional --detailed mode that provides extended information.

### Search Functionality:
Enables searching for items by name or pattern, supporting wildcards (*) and case-insensitive searches (--ignore-case).

### Permanent Deletion (Empty Bin):
Permits users to permanently remove individual items or clear the entire recycle bin, with confirmation prompts or a --force flag to skip them.

### Storage Quota Management:
Includes config_quota() and check_quota() functions to limit the maximum bin size and automatically delete the oldest files when the quota is exceeded.

### Automatic Cleanup by Age:
Implements a time-based cleanup mechanism that removes files older than a configurable number of days (config_cleanup() and auto_cleanup()).

### File Preview:
Allows previewing the first few lines of text files or listing directory contents before restoration or deletion.

### Statistics Summary:
Displays real-time statistics about the recycle bin, including total number of items and total storage usage in human-readable format.

### Configurable Parameters:
Provides user commands to easily configure maximum bin size (config_bin_size) and retention time (config_bin_time).

### Logging System:
Maintains a detailed recyclebin.log file recording all actions (deletion, restoration, and permanent removal) with timestamps.

### Built-in Help Menu:
Offers a complete usage guide accessible with ./recycle_bin.sh help, describing all commands, flags, and examples.
## Configuration
The Linux recycle bin script allows you to configure two main settings: the **maximum bin size** and the **maximum time files can stay in the bin.**

To set the maximum size, use    

`./recycle_bin.sh config_bin_size <MAX_SIZE_MB>`,

where `<MAX_SIZE_MB>` is the value in megabytes. If the bin exceeds this size, the oldest files are automatically deleted.


To set the maximum time, use 

`./recycle_bin.sh config_bin_time <NUMBER_OF_DAYS>`

, where `<NUMBER_OF_DAYS>` is the number of days a file can remain in the bin before being removed. 

These settings are stored in the file $HOME/.recycle_bin/config and are read by the script on each run. The size limit is enforced by **check_quota()**, which deletes the oldest files when necessary, while the time limit is enforced by **auto_cleanup()**, which automatically removes files older than the specified number of days.
## Examples
[Detailed usage examples with screenshots]
## Known Issues
No limitations found
## References
Use of AI to grasp concepts.

