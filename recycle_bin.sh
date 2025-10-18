#!/bin/bash

#################################################
# Linux Recycle Bin Simulation
# Author: [Your Name]
# Date: [Date]
# Description: Shell-based recycle bin system
#################################################
# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"
LOG_FILE="$RECYCLE_BIN_DIR/recyclebin.log"

# Color codes for output (optional)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {

    mkdir -p "$FILES_DIR" || { echo -e "${RED}Erro ao criar diretorios.${NC}"; return 1; }

    if [ ! -f "$METADATA_FILE" ]; then
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
    fi

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi

    echo -e "${GREEN}Recycle bin inicializado em $RECYCLE_BIN_DIR${NC}"
    return 0
}

#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
local timestamp=$(date +%s)
local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
echo "${timestamp}_${random}"
}


#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
# TODO: Implement this function
local file_path="$1"
# Validate input
if [ -z "$file_path" ]; then
echo -e "${RED}Error: No file specified${NC}"
return 1
fi
# Check if file exists
if [ ! -e "$file_path" ]; then
echo -e "${RED}Error: File '$file_path' does not exist${NC}"
return 1
fi
# Generate unique ID for this file
local unique_id
unique_id=$(generate_unique_id)

# Get absolute path
local abs_path
abs_path=$(realpath "$file_path" 2>/dev/null)

# Prevent deleting the recycle bin itself
if [[ "$abs_path" == "$RECYCLE_BIN_DIR"* ]]; then
    echo -e "${RED}Error: Cannot delete the recycle bin itself${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR Attempted to delete recycle bin: $file_path" >> "$LOG_FILE"
    return 1
fi

# Check read/write permissions
if [ ! -r "$file_path" ] || [ ! -w "$file_path" ]; then
    echo -e "${RED}Error: No read/write permissions for '$file_path'${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR No permission: $file_path" >> "$LOG_FILE"
    return 1
fi

# Destination path in recycle bin
local destination="$FILES_DIR/$unique_id"

# Collect metadata
local filename
filename=$(basename "$file_path")
local timestamp
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
local filesize
filesize=$(du -b "$file_path" 2>/dev/null | cut -f1)
local filetype
[ -d "$file_path" ] && filetype="directory" || filetype="file"
local permissions
permissions=$(stat -c "%a" "$file_path")
local owner
owner=$(stat -c "%U:%G" "$file_path")

# Move file or directory to recycle bin
mv "$file_path" "$destination" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to move '$file_path'${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR Failed to move $file_path" >> "$LOG_FILE"
    return 1
fi

# Append metadata entry to metadata.db
echo "$unique_id,$filename,$abs_path,$timestamp,$filesize,$filetype,$permissions,$owner" >> "$METADATA_FILE"

# Log operation
echo "$(date '+%Y-%m-%d %H:%M:%S') INFO Deleted: $abs_path -> $destination" >> "$LOG_FILE"

# Feedback to user
echo -e "${GREEN}Deleted '$filename' (ID: $unique_id)${NC}"

echo "Delete function called with: $file_path"
return 0
}


#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################
list_recycled() {
# TODO: Implement this function
echo "=== Recycle Bin Contents ==="
# Check if metadata file exists and is not empty
if [ ! -s "$METADATA_FILE" ]; then
    echo -e "${YELLOW}Recycle bin is empty.${NC}"
    return 0
fi

# Skip header line and read data
local detailed_mode=false
if [ "$1" == "--detailed" ]; then
    detailed_mode=true
fi

# Print header for normal mode
if [ "$detailed_mode" = false ]; then
    printf "%-15s %-25s %-20s %-10s\n" "ID" "Original Name" "Deletion Date" "Size"
    printf "%-15s %-25s %-20s %-10s\n" "---------------" "-------------------------" "--------------------" "----------"
fi

local total_size=0
local count=0

# Read metadata line by line (skip header)
while IFS=',' read -r id name path date size type perms owner; do
    ((count++))
    total_size=$((total_size + size))

    # Convert size to human-readable format
    if [ "$size" -lt 1024 ]; then
        hr_size="${size}B"
    elif [ "$size" -lt 1048576 ]; then
        hr_size="$(awk "BEGIN {printf \"%.1fKB\", $size/1024}")"
    elif [ "$size" -lt 1073741824 ]; then
        hr_size="$(awk "BEGIN {printf \"%.1fMB\", $size/1048576}")"
    else
        hr_size="$(awk "BEGIN {printf \"%.1fGB\", $size/1073741824}")"
    fi

    # Truncate ID for display (first 12 chars)
    short_id="${id:0:12}"

    if [ "$detailed_mode" = true ]; then
        echo -e "${GREEN}ID:${NC} $id"
        echo -e "  ${YELLOW}Name:${NC} $name"
        echo -e "  ${YELLOW}Path:${NC} $path"
        echo -e "  ${YELLOW}Deleted:${NC} $date"
        echo -e "  ${YELLOW}Size:${NC} $hr_size"
        echo -e "  ${YELLOW}Type:${NC} $type"
        echo -e "  ${YELLOW}Perms:${NC} $perms"
        echo -e "  ${YELLOW}Owner:${NC} $owner"
        echo "-------------------------------------------"
    else
        printf "%-15s %-25s %-20s %-10s\n" "$short_id" "$name" "$date" "$hr_size"
    fi
done < <(tail -n +2 "$METADATA_FILE")

# Wait for subshell to finish
wait

# Convert total size to human-readable
if [ "$total_size" -lt 1024 ]; then
    total_hr="${total_size}B"
elif [ "$total_size" -lt 1048576 ]; then
    total_hr="$(awk "BEGIN {printf \"%.1fKB\", $total_size/1024}")"
elif [ "$total_size" -lt 1073741824 ]; then
    total_hr="$(awk "BEGIN {printf \"%.1fMB\", $total_size/1048576}")"
else
    total_hr="$(awk "BEGIN {printf \"%.1fGB\", $total_size/1073741824}")"
fi

# Summary
echo
echo -e "${GREEN}Total items:${NC} $count"
echo -e "${GREEN}Total size:${NC} $total_hr"

return 0
}
: <<'EOF'
#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
# TODO: Implement this function
local file_id="$1"
if [ -z "$file_id" ]; then
echo -e "${RED}Error: No file ID specified${NC}"
return 1
fi
# Your code here
# Hint: Search metadata for matching ID
# Hint: Get original path from metadata
# Hint: Check if original path exists
# Hint: Move file back and restore permissions
# Hint: Remove entry from metadata
return 0
}
#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
# TODO: Implement this function
# Your code here
# Hint: Ask for confirmation
# Hint: Delete all files in FILES_DIR
# Hint: Reset metadata file
return 0
}
#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
search_recycled() {
# TODO: Implement this function
local pattern="$1"
# Your code here
# Hint: Use grep to search metadata
return 0
}
#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
cat << EOF
Linux Recycle Bin - Usage Guide
SYNOPSIS:
$0 [OPTION] [ARGUMENTS]
OPTIONS:
delete <file> Move file/directory to recycle bin
list List all items in recycle bin
restore <id> Restore file by ID
search <pattern> Search for files by name
empty Empty recycle bin permanently
help Display this help message
EXAMPLES:
$0 delete myfile.txt
$0 list
$0 restore 1696234567_abc123
$0 search "*.pdf"
$0 empty
EOF
return 0
}
#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
# Initialize recycle bin
initialize_recyclebin
# Parse command line arguments
case "$1" in
delete)
shift
delete_file "$@"
;;
list)
list_recycled
;;
restore)
restore_file "$2"
;;
search)
search_recycled "$2"
;;
empty)
empty_recyclebin
;;
help|--help|-h)
display_help
;;
*)
echo "Invalid option. Use 'help' for usage information."
exit 1
;;
esac
}
# Execute main function with all arguments
main "$@"

EOF
