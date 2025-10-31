#!/bin/bash

#################################################
# Linux Recycle Bin Simulation
# Author: Tomás Nogueira de Meneses Xavier and Guilherme da Silva Gomes
# Date: 2025-10-25
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

    mkdir -p "$FILES_DIR" || { echo -e "${RED}Error in creating directory.${NC}"; return 1; }

    if [ ! -f "$METADATA_FILE" ]; then
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" > "$METADATA_FILE"
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        # Default configuration: 10 KB and 10 days
        echo "MAX_SIZE_MB=1000" > "$CONFIG_FILE"
        echo "NUMBER_OF_DAYS=10" >> "$CONFIG_FILE"
    fi

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi

    echo -e "${GREEN}Recycle bin initialized at $RECYCLE_BIN_DIR${NC}"
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
    local had_error=0 
    
    for file_path in "$@"; do
        if [ -z "$file_path" ]; then
            echo -e "${RED}Error: No file specified${NC}"
            had_error=1  
            continue
        fi

        if [ ! -L "$file_path" ] && [ ! -e "$file_path" ]; then
            echo -e "${RED}Error: File '$file_path' does not exist${NC}"
            had_error=1  
            continue
        fi

        local unique_id
        unique_id=$(generate_unique_id)

        local abs_path
        if [ -L "$file_path" ]; then
            abs_path=$(readlink -f "$file_path")
        else
            abs_path=$(realpath "$file_path" 2>/dev/null)
        fi

        if [[ "$abs_path" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${RED}Error: Cannot delete the recycle bin itself${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR Attempted to delete recycle bin: $file_path" >> "$LOG_FILE"
            had_error=1   
            continue
        fi

        if [ -L "$file_path" ]; then
            if [ ! -w "$(dirname "$file_path")" ]; then
                echo -e "${RED}Error: No write permission on directory of '$file_path'.${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR No permission: $file_path" >> "$LOG_FILE"
                had_error=1   
                continue
            fi
        else
            if [ ! -w "$file_path" ] || [ ! -w "$(dirname "$file_path")" ]; then
                echo -e "${RED}Error: No write permissions for '$file_path' or its directory.${NC}"
                echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR No permission: $file_path" >> "$LOG_FILE"
                had_error=1   
                continue
            fi
        fi

        local destination="$FILES_DIR/$unique_id"

        local filename
        filename=$(basename "$file_path")
        
        local safe_filename="$filename"
        if [ ${#filename} -gt 255 ]; then
            safe_filename="${unique_id}"
            echo -e "${YELLOW}Warning: filename too long (${#filename} bytes), storing with ID as name${NC}"
        fi
        
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        local filesize filetype permissions owner
        if [ -L "$file_path" ]; then
            filetype="symlink"
            filesize=$(stat -c "%s" "$file_path")
            permissions=$(stat -c "%a" "$file_path")
            owner=$(stat -c "%U:%G" "$file_path")
        else
            filesize=$(du -b "$file_path" 2>/dev/null | cut -f1)
            [ -d "$file_path" ] && filetype="directory" || filetype="file"
            permissions=$(stat -c "%a" "$file_path")
            owner=$(stat -c "%U:%G" "$file_path")
        fi

        mv "$file_path" "$destination" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to move '$file_path'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR Failed to move $file_path" >> "$LOG_FILE"
            had_error=1  
            continue
        fi

        echo "$unique_id,$filename,$abs_path,$timestamp,$filesize,$filetype,$permissions,$owner" >> "$METADATA_FILE"

        echo "$(date '+%Y-%m-%d %H:%M:%S') INFO Deleted: $abs_path -> $destination" >> "$LOG_FILE"

        echo -e "${GREEN}Deleted '$filename' (ID: $unique_id)${NC}"

    done

    check_quota
    
    return "$had_error"
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
# Check if there are items in the recycle bin
if [ ! -d "$FILES_DIR" ] || [ -z "$(ls -A "$FILES_DIR")" ]; then
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
        echo -e "${RED}Error: No file ID or name specified${NC}"
        return 1
    fi

    # Procurar por ID ou nome literal no metadata
    local metadata_line
    metadata_line=$(grep -F "$file_id" "$METADATA_FILE" | head -n 1)

    if [ -z "$metadata_line" ]; then
        echo -e "${RED}Error: File ID or name not found in metadata${NC}"
        return 1
    fi

    # Extrair campos da metadata
    IFS=',' read -r id name orig_path date size type perms owner <<< "$metadata_line"

    # Caminho real no recycle bin
    local bin_file="$FILES_DIR/$id"

    # Verificar se o arquivo existe no recycle bin
    if [ ! -e "$bin_file" ]; then
        echo -e "${RED}Error: File '$bin_file' not found in recycle bin${NC}"
        return 1
    fi

    # Determinar diretório de destino e criar se necessário
    local dest_dir
    dest_dir=$(dirname "$orig_path")
    if [ ! -d "$dest_dir" ]; then
        mkdir -p "$dest_dir" || {
            echo -e "${RED}Error: Cannot create directory $dest_dir${NC}"
            return 1
        }
    fi

    local dest_path="$orig_path"
    # If the original filename is too long for the filesystem, create a safe truncated name
    local MAX_NAME_LEN=255
    local orig_name
    orig_name=$(basename "$orig_path")
    if [ ${#orig_name} -gt $MAX_NAME_LEN ]; then
        # Truncate and add a short id suffix to keep uniqueness
        local prefix_len=200
        local short_id_suffix
        short_id_suffix="${id:0:6}"
        local safe_name
        safe_name="${orig_name:0:prefix_len}_$short_id_suffix"
        dest_path="${dest_dir}/${safe_name}"
        echo -e "${YELLOW}Warning: original filename is longer than $MAX_NAME_LEN bytes; it will be restored as '$safe_name'.${NC}"
    fi

    if [ -e "$dest_path" ]; then
        echo -e "${YELLOW}File $dest_path already exists.${NC}"
        echo "Choose action: [O]verwrite / [R]ename / [C]ancel"
        read -r choice
        case "$choice" in
            [Oo]* )
                ;;
            [Rr]* )
                timestamp=$(date +%Y%m%d%H%M%S)
                dest_path="${dest_dir}/${name}_${timestamp}"
                ;;
            [Cc]* )
                echo "Restoration canceled."
                return 1
                ;;
            * )
                echo "Invalid option. Canceling."
                return 1
                ;;
        esac
    fi

    # Mover arquivo do recycle bin para o destino
    if ! mv "$bin_file" "$dest_path"; then
        echo -e "${RED}Error: Failed to restore file. Check permissions and disk space.${NC}"
        return 1
    fi

    # Restaurar permissões originais
    chmod "$perms" "$dest_path" 2>/dev/null || echo -e "${YELLOW}Warning: Could not restore permissions.${NC}"

    # Remover entrada do metadata
    grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

    # Feedback e log
    echo -e "${GREEN}File restored to $dest_path successfully.${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') RESTORE $id -> $dest_path" >> "$LOG_FILE"

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
    local target="$1"
    local force="$2"
    local deleted_count=0
    local deleted_size=0

    # Função interna para apagar uma linha de metadata e arquivo
    _delete_item() {
        local id="$1"
        local metadata_line
        metadata_line=$(grep -F "$id" "$METADATA_FILE" | head -n 1)
        if [ -z "$metadata_line" ]; then
            echo -e "${YELLOW}Warning: File ID $id not found in metadata.${NC}"
            return
        fi
        IFS=',' read -r id name path date size type perms owner <<< "$metadata_line"
        local file_path="$FILES_DIR/$id"
        if [ -e "$file_path" ]; then
            if rm -rf "$file_path"; then
                deleted_count=$((deleted_count + 1))
                size_num=$(printf '%s' "$size" | tr -dc '0-9')
                if [ -z "$size_num" ]; then
                    size_num=0
                fi
                deleted_size=$((deleted_size + size_num))
                echo "$(date '+%Y-%m-%d %H:%M:%S') PERMANENT DELETE $id -> $file_path" >> "$LOG_FILE"
            fi
        fi
        # Remove do metadata
        grep -v "^$id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
    }

    if [ "$target" == "--force" ]; then
        force="true"
        target=""
    fi

    if [ -n "$target" ] && [ "$force" != "true" ]; then
        echo -n "Are you sure you want to permanently delete item $target? [y/N]: "
        read -r confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && echo "Operation canceled." && return 1
    elif [ -z "$target" ] && [ "$force" != "true" ]; then
        echo -n "Are you sure you want to permanently delete ALL items in recycle bin? [y/N]: "
        read -r confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && echo "Operation canceled." && return 1
    fi

    # Apagar item específico
    if [ -n "$target" ]; then
        _delete_item "$target"
    else
        # Apagar todos --- usar process substitution para evitar subshell
        while IFS=',' read -r id name path date size type perms owner; do
            _delete_item "$id"
        done < <(tail -n +2 "$METADATA_FILE")
    fi

    # Mostrar resumo
        echo -e "${GREEN}Deleted items: $deleted_count${NC}"
        echo -e "${GREEN}Total freed size: $deleted_size bytes${NC}"
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
local case_insensitive=false

    # Verificação de parâmetros
    if [ -z "$pattern" ]; then
        echo -e "${RED}Error: No search pattern provided${NC}"
        echo "Usage: ./recycle_bin.sh search <pattern> [--ignore-case]"
        return 1
    fi

    # Verificar se o segundo parâmetro é --ignore-case
    if [ "$2" == "--ignore-case" ]; then
        case_insensitive=true
    fi

    # Verificar se há itens na lixeira
    if [ ! -s "$METADATA_FILE" ]; then
        echo -e "${YELLOW}Recycle bin is empty.${NC}"
        return 0
    fi

    # Converter wildcard em expressão regular (para grep)
    local regex_pattern="${pattern//\*/.*}"

    # Escolher comando grep conforme opção case-insensitive
    local grep_cmd="grep -E"
    if [ "$case_insensitive" = true ]; then
        grep_cmd="grep -Ei"
    fi

    # Pular o cabeçalho e procurar correspondências
    local matches
    matches=$(tail -n +2 "$METADATA_FILE" | $grep_cmd "$regex_pattern")

    if [ -z "$matches" ]; then
        echo -e "${YELLOW}File not found matching pattern '${pattern}'.${NC}"
        return 1
    fi

    # Cabeçalho bonito
    printf "%-15s %-25s %-50s %-20s\n" "ID" "Original Name" "Original Path" "Deletion Date"
    printf "%-15s %-25s %-50s %-20s\n" "---------------" "-------------------------" "--------------------------------------------------" "--------------------"

    # Exibir resultados
    while IFS=',' read -r id name path date size type perms owner; do
        printf "%-15s %-25s %-50s %-20s\n" "$id" "$name" "$path" "$date"
    done <<< "$matches"

    local count
    count=$(echo "$matches" | wc -l)
    echo
    echo -e "${GREEN}Total matches:${NC} $count"

return 0
}
#################################################
# Function: config_quota & check_quota
# Description: Implement size limits for the recycle bin, Auto-delete the oldest files when the quota is exceeded
# Parameters: $1 = max size of the bin
# Returns: 0
#################################################
config_quota(){
    local MAX_SIZE_MB="$1"

    if ! [[ "$MAX_SIZE_MB" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please provide a valid number for the size of the bin.${NC}"
        return 1
    fi

    local temp_config
    temp_config=$(mktemp)
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^MAX_SIZE_MB=" "$CONFIG_FILE" > "$temp_config"
    fi

    echo "MAX_SIZE_MB=$MAX_SIZE_MB" >> "$temp_config"

    mv "$temp_config" "$CONFIG_FILE"

    echo -e "${GREEN}Maximum space for the recycle bin set to ${MAX_SIZE_MB}KB.${NC}"
}

check_quota() {
    local max_size_b=$((MAX_SIZE_MB * 1024 * 1024))
    local current_size
    current_size=$(du -sb "$FILES_DIR" | cut -f1)

    if [ "$current_size" -le "$max_size_b" ]; then
        return 0
    fi

    echo -e "${YELLOW}Quota exceeded. Cleaning up oldest files...${NC}"

    local ids_to_delete=()
    while [ "$current_size" -gt "$max_size_b" ]; do
        local oldest_line
        oldest_line=$(tail -n +2 "$METADATA_FILE" | sort -t, -k4 | head -n 1)
        
        if [ -z "$oldest_line" ]; then
            break # Não há mais nada para apagar
        fi

        local oldest_id
        oldest_id=$(echo "$oldest_line" | cut -d, -f1)
        local oldest_size
        oldest_size=$(echo "$oldest_line" | cut -d, -f5)

        ids_to_delete+=("$oldest_id")
        current_size=$((current_size - oldest_size))

        local temp_metadata
        temp_metadata=$(mktemp)
        grep -v "^$oldest_id," "$METADATA_FILE" > "$temp_metadata"
        mv "$temp_metadata" "$METADATA_FILE"
    done

    for id in "${ids_to_delete[@]}"; do
        echo "Permanently deleting file (quota): $id"
        rm -rf "$FILES_DIR/$id"
    done
}
#################################################
# Function: config_cleanup & auto_cleanup
## Description: Automatically delete files older than N days
## Parameters: $1 = number of days
## Returns: 0
##################################################
config_cleanup() {
    local number_of_days="$1"

    if ! [[ "$number_of_days" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please provide a valid number for the number of days.${NC}"
        return 1
    fi

    local temp_config
    temp_config=$(mktemp)
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^NUMBER_OF_DAYS=" "$CONFIG_FILE" > "$temp_config"
    fi

    echo "NUMBER_OF_DAYS=$number_of_days" >> "$temp_config"

    mv "$temp_config" "$CONFIG_FILE"

    echo -e "${GREEN}Maximum time for a file in the bin set to ${number_of_days} days.${NC}"
}

auto_cleanup(){
    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 1 ]; then
        return 0 # Ficheiro de metadados vazio ou só com cabeçalho
    fi

    local temp_metadata
    temp_metadata=$(mktemp)
    # Copia o cabeçalho para o novo ficheiro de metadados
    head -n 1 "$METADATA_FILE" > "$temp_metadata"

    local current_ts
    current_ts=$(date +%s)
    local cutoff_ts=$((current_ts - (NUMBER_OF_DAYS * 86400))) # 86400s = 1 dia

    local ids_to_delete=()

    tail -n +2 "$METADATA_FILE" | while IFS=',' read -r line; do
        local deletion_date
        deletion_date=$(echo "$line" | cut -d, -f4)
        local file_ts
        file_ts=$(date -d "$deletion_date" +%s 2>/dev/null || echo 0)
        
        if [ "$file_ts" -lt "$cutoff_ts" ]; then
            local id_to_delete
            id_to_delete=$(echo "$line" | cut -d, -f1)
            ids_to_delete+=("$id_to_delete")
        else
            echo "$line" >> "$temp_metadata"
        fi
    done

    mv "$temp_metadata" "$METADATA_FILE"

    if [ "${#ids_to_delete[@]}" -eq 0 ]; then
        return 0 # Nada para apagar
    fi

    for id in "${ids_to_delete[@]}"; do
        echo "Permanently deleting file (cleanup): $id"
        rm -rf "$FILES_DIR/$id"
    done
}
#
##################################################
## Function: preview_file
## Description: Show a preview of a file in the recycle bin
## Parameters: $1 - file ID
## Returns: 0
##################################################
preview_file() {
    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No ID or name specified for preview.${NC}"
        return 1
    fi

    if [ ! -s "$METADATA_FILE" ]; then
        echo -e "${YELLOW}Recycle bin is empty.${NC}"
        return 1
    fi

    # Encontrar a linha de metadata correspondente (por ID ou por nome)
    local metadata_line
    metadata_line=$(grep -F "$file_id" "$METADATA_FILE" | head -n 1)

    if [ -z "$metadata_line" ]; then
        echo -e "${RED}Error: File ID or name not found in metadata${NC}"
        return 1
    fi

    local id name path date size type perms owner
    IFS=',' read -r id name path date size type perms owner <<< "$metadata_line"

    local bin_path="$FILES_DIR/$id"
    if [ ! -e "$bin_path" ]; then
        echo -e "${RED}Error: File not found in recycle bin: $bin_path${NC}"
        return 1
    fi

    echo "=== Preview: $name (ID: $id) ==="

    if [ "$type" != "file" ]; then
        # Diretório ou outro tipo: listar conteúdo
        ls -la "$bin_path"
        return 0
    fi

    # Tentar detetar tipo com 'file' (se disponível)
    if command -v file >/dev/null 2>&1; then
        mime=$(file -b --mime-type "$bin_path" 2>/dev/null || echo "application/octet-stream")
        case "$mime" in
            text/*|*/xml|*/json|*/csv)
                head -n 10 "$bin_path"
                ;;
            *)
                echo "(binary or unsupported mime-type: $mime)"
                ls -la "$bin_path"
                ;;
        esac
    else
        # Fallback para sistemas sem 'file'
        if grep -Iq . "$bin_path" 2>/dev/null; then
            head -n 10 "$bin_path"
        else
            echo "(binary file - preview not available)"
            ls -la "$bin_path"
        fi
    fi

    return 0
}


##################################################
## Function: show_statistics
## Description: Show statistics about the recycle bin
## Parameters: None
## Returns: 0
##################################################
show_statistics() {
    echo -e "${GREEN}--- Estatísticas da Lixeira ---${NC}"

    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 1 ]; then
        echo "Itens na lixeira: 0"
        echo "Tamanho total: 0B"
        return 0
    fi

    local total_size=0
    local count=0

    while IFS= read -r size; do
        ((count++))
        total_size=$((total_size + size))
    done < <(tail -n +2 "$METADATA_FILE" | cut -d, -f5)

    local total_hr
    if [ "$total_size" -lt 1024 ]; then
        total_hr="${total_size}B"
    elif [ "$total_size" -lt 1048576 ]; then
        total_hr="$(awk "BEGIN {printf \"%.1fKB\", $total_size/1024}")"
    elif [ "$total_size" -lt 1073741824 ]; then
        total_hr="$(awk "BEGIN {printf \"%.1fMB\", $total_size/1048576}")"
    else
        total_hr="$(awk "BEGIN {printf \"%.1fGB\", $total_size/1073741824}")"
    fi

    echo "Itens na lixeira: $count"
    echo "Tamanho total: $total_hr"

    return 0
}


load_config() {
    # Defaults (used when config values are absent)
    MAX_SIZE_MB=10
    NUMBER_OF_DAYS=10

    if [ -f "$CONFIG_FILE" ]; then
        local size_line
        size_line=$(grep "^MAX_SIZE_MB=" "$CONFIG_FILE") 
        if [ -n "$size_line" ]; then
            MAX_SIZE_MB=$(echo "$size_line" | cut -d'=' -f2) 
        fi
        local days_line
        days_line=$(grep "^NUMBER_OF_DAYS=" "$CONFIG_FILE")
        if [ -n "$days_line" ]; then
            NUMBER_OF_DAYS=$(echo "$days_line" | cut -d'=' -f2)
        fi
    fi
}
##################################################
## Function: display_help
## Description: Shows usage information
## Parameters: None
## Returns: 0
##################################################
display_help() {
    local size_config
    size_config=$(grep "^MAX_SIZE_MB=" "$CONFIG_FILE")
    local days_config
    days_config=$(grep "^NUMBER_OF_DAYS=" "$CONFIG_FILE")
cat << EOF
Linux Recycle Bin - Usage Guide

SYNOPSIS:
  $0 [OPTION] [ARGUMENTS]

OPTIONS:
  delete <"file">        Move file or directory to recycle bin
  list [--detailed]    List all items in recycle bin
  restore <id>         Restore file by ID
  search <pattern>     Search for files by name or original path
  empty [id|--force]   Permanently delete items (single or all)
  help                 Display this help message
  config_bin_time      Configures the max number of days for a file to stay in the bin
  config_bin_size      Configures the max size for the recycle bin
  show_statistics      Show statistics about the recycle bin
  preview <id/name>    Shows the first ten lines of a file in the recycle bin

ADDITIONAL FLAGS:
  --detailed           Show extended information when listing files
  --ignore-case        Perform case-insensitive searches
  --force              Skip confirmation prompts when emptying bin

EXAMPLES:
  $0 delete "myfile.txt"
  $0 list
  $0 list --detailed
  $0 restore 1696234567_abc123
  $0 restore "ficheiro.txt"
  $0 search "*.pdf"
  $0 search "report" --ignore-case
  $0 empty
  $0 empty --force
  $0 help
  $0 --help
  $0 -h

CONFIGURATION FILES:
  Recycle Bin Directory : $RECYCLE_BIN_DIR
  Metadata Database      : $METADATA_FILE
  Log File               : $LOG_FILE
  Config File            : $CONFIG_FILE

NOTES:
  • Files moved to the recycle bin can be restored anytime before
    being permanently deleted.
  • Use '--force' carefully when emptying the bin — this action
    cannot be undone!
  • Maximum time for a file in the bin is currently set to: ${days_config#*=} days
  • Maximum size for the bin is currently set to: ${size_config#*=}MB
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
    load_config

    # Exit se nenhum argumento for passado
    if [ -z "$1" ]; then
        echo "No command provided. Use 'help' for usage information."
        exit 1
    fi

    # Parse command line arguments
    case "$1" in
        delete)
            shift
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: No file specified for deletion.${NC}"
                exit 1
            fi
            delete_file "$@"
            ;;
        list)
            shift
            list_recycled "$1"   # passa --detailed se houver
            ;;
        restore)
            shift
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: No ID or filename specified for restore.${NC}"
                exit 1
            fi
            restore_file "$@"
            ;;
        search)
            shift
            if [ $# -eq 0 ]; then
                echo -e "${RED}Error: No pattern specified for search.${NC}"
                exit 1
            fi
            search_recycled "$@"
            ;;
        empty)
            shift
            empty_recyclebin "$@"
            ;;
        config_bin_time)
            shift
            config_cleanup "$@" # Nova opção para configurar numero de dias 
            ;;
        config_bin_size)
            shift
            config_quota   "$@" # Nova opção para configurar tamanho do lixo
            ;;
        show_statistics)
            shift
            show_statistics
            ;;
        preview)
            shift
            preview_file "$@"  # Nova opção para preview de arquivos
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo -e "${RED}Invalid command: $1${NC}"
            echo "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

main "$@"


