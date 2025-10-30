#!/bin/bash
# Test Suite for Recycle Bin System
SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0
# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
# Test Helper Functions
setup() {
mkdir -p "$TEST_DIR"
rm -rf ~/.recycle_bin
}
teardown() {
rm -rf "$TEST_DIR"
rm -rf ~/.recycle_bin
}
assert_success() {
if [ $? -eq 0 ]; then
echo -e "${GREEN}✓ PASS${NC}: $1"
((PASS++))
else
echo -e "${RED}✗ FAIL${NC}: $1"
((FAIL++))
fi
}
assert_fail() {
if [ $? -ne 0 ]; then
echo -e "${GREEN}✓ PASS${NC}: $1"
((PASS++))
else
echo -e "${RED}✗ FAIL${NC}: $1"
((FAIL++))
fi
}
# Test Cases
test_initialization() {
echo "=== Test: Initialization ==="
setup
$SCRIPT help > /dev/null
assert_success "Initialize recycle bin"
[ -d ~/.recycle_bin ] && echo "✓ Directory created"
[ -f ~/.recycle_bin/metadata.db ] && echo "✓ Metadata file created"
}
test_delete_file() {
echo "=== Test: Delete File ==="
setup
echo "test content" > "$TEST_DIR/test.txt"
$SCRIPT delete "$TEST_DIR/test.txt"
assert_success "Delete existing file"
[ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original
location"
}
test_list_empty() {
echo "=== Test: List Empty Bin ==="
setup
$SCRIPT list | grep -q "empty"
assert_success "List empty recycle bin"
}
test_restore_file() {
echo "=== Test: Restore File ==="
setup
echo "test" > "$TEST_DIR/restore_test.txt"
$SCRIPT delete "$TEST_DIR/restore_test.txt"
# Get file ID from list
ID=$($SCRIPT list | grep "restore_test" | awk '{print $1}')
$SCRIPT restore "$ID"
assert_success "Restore file"
[ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
}
test_delete_multiple_files() {
echo "=== Test: Delete Multiple Files ==="
setup
echo "file1" > "$TEST_DIR/file1.txt"
echo "file2" > "$TEST_DIR/file2.txt"
$SCRIPT delete "$TEST_DIR/file1.txt" "$TEST_DIR/file2.txt"
assert_success "Delete multiple files"
[ ! -f "$TEST_DIR/file1.txt" ] && [ ! -f "$TEST_DIR/file2.txt" ] && echo "✓ Both files removed"
}
test_delete_empty_directory() {
echo "=== Test: Delete Empty Directory ==="
setup
mkdir "$TEST_DIR/empty_dir"
$SCRIPT delete "$TEST_DIR/empty_dir"
assert_success "Delete empty directory"
[ ! -d "$TEST_DIR/empty_dir" ] && echo "✓ Directory removed"
}
test_delete_directory() {
echo "=== Test: Delete Directory ==="
setup
mkdir "$TEST_DIR/dir_to_delete"
echo "file_in_dir" > "$TEST_DIR/dir_to_delete/file.txt"
$SCRIPT delete "$TEST_DIR/dir_to_delete"
assert_success "Delete directory"
[ ! -d "$TEST_DIR/dir_to_delete" ] && echo "✓ Directory removed"
}
test_list_with_files() {
echo "=== Test: List with Files ==="
setup
echo "fileA" > "$TEST_DIR/fileA.txt"
$SCRIPT delete "$TEST_DIR/fileA.txt"
LIST_OUTPUT=$($SCRIPT list)
echo "$LIST_OUTPUT" | grep -q "fileA.txt"
assert_success "List recycle bin with files"
}
test_restore_to_nonexistent_directory() {
echo "=== Test: Restore to Nonexistent Directory ==="
setup
echo "test" > "$TEST_DIR/nonexistent_dir_test.txt"
$SCRIPT delete "$TEST_DIR/nonexistent_dir_test.txt"
ID=$($SCRIPT list | grep "nonexistent_dir_test" | awk '{print $1}')
rm -rf "$TEST_DIR"
$SCRIPT restore "$ID"
assert_success "Restore file to nonexistent directory"
[ -f "$TEST_DIR/nonexistent_dir_test.txt" ] && echo "✓ File restored to new directory"
}
test_empty_bin() {
echo "=== Test: Empty Recycle Bin ==="
setup
echo "temp" > "$TEST_DIR/temp.txt"
$SCRIPT delete "$TEST_DIR/temp.txt"
$SCRIPT empty --force
assert_success "Empty recycle bin"
LIST_OUTPUT=$($SCRIPT list)
echo "$LIST_OUTPUT" | grep -q "empty"
}
test_search(){
echo "=== Test: Search in Recycle Bin ==="
setup
echo "findme" > "$TEST_DIR/findme.txt"
$SCRIPT delete "$TEST_DIR/findme.txt"
SEARCH_OUTPUT=$($SCRIPT search "findme")
echo "$SEARCH_OUTPUT" | grep -q "findme.txt"
assert_success "Search for deleted file"
}
test_search_nonexistent(){
echo "=== Test: Search Nonexistent File in Recycle Bin ==="
setup
SEARCH_OUTPUT=$($SCRIPT search "nonexistentfile")
echo "$SEARCH_OUTPUT" | grep -q "not found"
assert_success "Search for nonexistent file"
}
test_help_command() {
echo "=== Test: Help Command ==="
HELP_OUTPUT=$($SCRIPT help)
echo "$HELP_OUTPUT" | grep -q "Usage Guide"
assert_success "Help command displays usage information"
}
test_delete_nonexistent_file() {
echo "=== Test: Delete Nonexistent File ==="
setup
OUTPUT=$($SCRIPT delete "$TEST_DIR/nonexistent.txt" 2>&1)
if echo "$OUTPUT" | grep -q "File '$TEST_DIR/nonexistent.txt' does not exist"; then
	assert_success "Delete nonexistent file (message)"
else
	echo "$OUTPUT"
	assert_fail "Delete nonexistent file"
fi
}
test_delete_file_without_permissions() {
    echo "=== Test: Delete File Without Permissions ==="
    setup
    touch "$TEST_DIR/protected.txt"
    chmod 000 "$TEST_DIR/protected.txt"
    # O script atual verifica a permissão do diretório pai para o 'mv'
    chmod 755 "$TEST_DIR"
    
    OUTPUT=$($SCRIPT delete "$TEST_DIR/protected.txt" 2>&1)
    
    # A verificação de permissão no seu script é mais complexa, vamos verificar a mensagem correta
    if echo "$OUTPUT" | grep -q "No read/write permissions"; then
        assert_success "Delete file without permissions (message)"
    else
        echo "OUTPUT: $OUTPUT"
        assert_fail "Delete file without permissions"
    fi
    # Cleanup
    chmod 755 "$TEST_DIR/protected.txt"
}

test_restore_to_filename_conflict() {
echo "=== Test: Restore to Filename Conflict ==="
setup
echo "original content" > "$TEST_DIR/conflict.txt"
$SCRIPT delete "$TEST_DIR/conflict.txt"
ID=$($SCRIPT list | grep "conflict.txt" | awk '{print $1}')
# Create a file with the same name to cause conflict
echo "new content" > "$TEST_DIR/conflict.txt"
$SCRIPT restore "$ID"
OUTPUT=$($SCRIPT restore "$ID" 2>&1)
# Check only the first message printed by the command for the conflict text
first_line=$(printf '%s\n' "$OUTPUT" | head -n1)
if echo "$first_line" | grep -q "already exists"; then
    assert_success "Restore to filename conflict (first message)"
else
    echo "First line: $first_line"
    echo "$OUTPUT"
    assert_fail "Restore to filename conflict"
fi
}
test_restore_with_nonexistent_id() {
    echo "=== Test: Restore with Nonexistent ID ==="
    setup
    OUTPUT=$($SCRIPT restore "nonexistent_id" 2>&1)
    if echo "$OUTPUT" | grep -q "File ID or name not found in metadata"; then
        assert_success "Restore with nonexistent ID (message)"
    else
        echo "OUTPUT: $OUTPUT"
        assert_fail "Restore with nonexistent ID"
    fi
}
test_handle_filenames_with_spaces(){
    echo "=== Test: Handle Filenames with Spaces ==="
    setup
    FILENAME="file with spaces.txt"
    touch "$TEST_DIR/$FILENAME"
    $SCRIPT delete "$TEST_DIR/$FILENAME"
    ID=$($SCRIPT list | grep "$FILENAME" | cut -d ' ' -f 1)
    $SCRIPT restore "$ID"    
    [ -f "$TEST_DIR/$FILENAME" ]
    assert_success "Check if file with spaces was restored"
}
test_handle_filenames_with_special_chars(){
echo "=== Test: Handle Filenames with Special Characters ==="
setup
echo "special content" > "$TEST_DIR/file@#$.txt"
$SCRIPT delete "$TEST_DIR/file@#$.txt"
[ ! -f "$TEST_DIR/file@#$.txt" ]
ID=$($SCRIPT list | grep "file@#$.txt" | awk '{print $1}')
$SCRIPT restore "$ID"
assert_success "Handle file with special characters in name"
}
test_handle_longnames(){
    echo "=== Test: Handle Long Filenames ==="
    setup
    LONG_NAME=$(printf 'a%.0s' {1..250})
    LONG_FILENAME="${LONG_NAME}.txt"
    touch "$TEST_DIR/$LONG_FILENAME"

    $SCRIPT delete "$TEST_DIR/$LONG_FILENAME"    
    [ ! -f "$TEST_DIR/$LONG_FILENAME" ]

    ID=$($SCRIPT list | grep "$LONG_FILENAME" | awk '{print $1}')
    if [ -z "$ID" ]; then
        echo "ERROR: Long name file not found in recycle bin list"
        assert_fail "Find long name file in list"
        return
    fi
    $SCRIPT restore "$ID"
    assert_success "Restore file with long name"    
}
test_handle_large_files(){
echo "=== Test: Handle Large Files ==="
setup
fallocate -l 100M "$TEST_DIR/large_file.bin"
$SCRIPT delete "$TEST_DIR/large_file.bin"
[ ! -f "$TEST_DIR/large_file.bin" ]
ID=$($SCRIPT list | grep "large_file.bin" | awk '{print $1}')
$SCRIPT restore "$ID"
assert_success "Handle large file deletion and restoration"
}
test_handle_symbolic_links(){
    echo "=== Test: Handle Symbolic Links ==="
    setup
    echo "original content" > "$TEST_DIR/original.txt"
    ln -s "$TEST_DIR/original.txt" "$TEST_DIR/symlink.txt" 
    $SCRIPT delete "$TEST_DIR/symlink.txt"
    [ ! -f "$TEST_DIR/symlink.txt" ] 
    ID=$($SCRIPT list | grep "symlink.txt" | awk '{print $1}')
    $SCRIPT restore "$ID"
    assert_success "Restore symbolic link"
}
test_handle_hidden_files() {
    echo "=== Test: Handle Hidden Files ==="
    setup
    FILENAME=".hiddenfile"
    touch "$TEST_DIR/$FILENAME"
    
    $SCRIPT delete "$TEST_DIR/$FILENAME"
    ID=$($SCRIPT list | grep "$FILENAME" | cut -d ' ' -f 1)
    $SCRIPT restore "$ID"
    assert_success "Restore hidden file"
}
test_delete_from_multiple_directories() {
    echo "=== Test: Delete from Multiple Directories ==="
    setup
    mkdir -p "$TEST_DIR/dir1" "$TEST_DIR/dir2"
    touch "$TEST_DIR/dir1/file1.txt" "$TEST_DIR/dir2/file2.txt"
    
    $SCRIPT delete "$TEST_DIR/dir1/file1.txt" "$TEST_DIR/dir2/file2.txt"
    
    [ ! -f "$TEST_DIR/dir1/file1.txt" ] && [ ! -f "$TEST_DIR/dir2/file2.txt" ] && echo "✓ Both files removed"
    assert_success "Delete files from multiple directories"
}

test_restore_to_readonly_directory() {
    echo "=== Test: Restore to Read-Only Directory ==="
    setup
    touch "$TEST_DIR/file.txt"
    $SCRIPT delete "$TEST_DIR/file.txt"
    ID=$($SCRIPT list | grep "file.txt" | cut -d ' ' -f 1)
    
    chmod 555 "$TEST_DIR"
    
    OUTPUT=$($SCRIPT restore "$ID" 2>&1)
    
    if echo "$OUTPUT" | grep -q "Failed to restore file"; then
        assert_success "Restore to read-only directory (message)"
    else
        echo "OUTPUT: $OUTPUT"
        assert_fail "Restore to read-only directory"
    fi
    # Cleanup
    chmod 755 "$TEST_DIR"
}

test_invalid_command() {
    echo "=== Test: Invalid Command ==="
    setup
    OUTPUT=$($SCRIPT invalidcommand 2>&1)
    if echo "$OUTPUT" | grep -q "Invalid command"; then
        assert_success "Invalid command shows error"
    else
        echo "OUTPUT: $OUTPUT"
        assert_fail "Invalid command"
    fi
}

test_missing_parameters() {
    echo "=== Test: Missing Parameters ==="
    setup
    OUTPUT=$($SCRIPT delete 2>&1)
    if echo "$OUTPUT" | grep -q "No file specified"; then
        assert_success "Missing parameters shows error"
    else
        echo "OUTPUT: $OUTPUT"
        assert_fail "Missing parameters"
    fi
}

test_delete_recycle_bin_itself() {
    echo "=== Test: Attempt to Delete Recycle Bin Itself ==="
    setup
    # Certificar que a lixeira existe
    $SCRIPT list > /dev/null
    
    OUTPUT=$($SCRIPT delete "$HOME/.recycle_bin" 2>&1)
    if echo "$OUTPUT" | grep -q "Cannot delete the recycle bin itself"; then
        assert_success "Attempt to delete recycle bin shows error"
    else
        echo "OUTPUT: $OUTPUT"
        assert_fail "Attempt to delete recycle bin"
    fi
}

test_corrupted_metadata() {
    echo "=== Test: Handle Corrupted Metadata ==="
    setup
    $SCRIPT list > /dev/null # Inicializa a lixeira
    
    # Adicionar uma linha corrompida (sem vírgulas suficientes)
    echo "corrupted_id,corrupted_file" >> ~/.recycle_bin/metadata.db
    
    # O teste passa se o comando 'list' não terminar com um erro fatal
    $SCRIPT list > /dev/null 2>&1
    assert_success "List does not crash with corrupted metadata"
}
test_error_insufficient_disk_space() { # AI was used on this test
    echo "=== Test: Error - Insufficient Disk Space ==="
    setup
    touch "$TEST_DIR/file_to_fail.txt"
    
    mv() { return 1; }
    export -f mv
    
    $SCRIPT delete "$TEST_DIR/file_to_fail.txt" > /dev/null 2>&1
    
    unset -f mv
    
    METADATA_ENTRIES=$(tail -n +2 ~/.recycle_bin/metadata.db | wc -l)
    if [ -f "$TEST_DIR/file_to_fail.txt" ] && [ "$METADATA_ENTRIES" -eq 0 ]; then
        assert_success "System remains consistent after disk space error"
    else
        assert_fail "System became inconsistent after disk space error"
    fi
}

test_error_permission_denied_on_delete() {
    echo "=== Test: Error - Permission Denied on Deletion ==="
    setup
    mkdir -p "$TEST_DIR/read_only_dir"
    touch "$TEST_DIR/read_only_dir/file.txt"
    chmod 555 "$TEST_DIR/read_only_dir" # Diretório read-only
    
    $SCRIPT delete "$TEST_DIR/read_only_dir/file.txt" > /dev/null 2>&1
    assert_fail "Script fails correctly when permission is denied on delete"
    
    chmod 755 "$TEST_DIR/read_only_dir"
}

test_error_concurrent_operations() {
    echo "=== Test: Error - Concurrent Operations Vulnerability ==="
    setup
    $SCRIPT list > /dev/null # Inicializa a lixeira

    touch "$TEST_DIR/file_A.txt"
    touch "$TEST_DIR/file_B.txt"

    $SCRIPT delete "$TEST_DIR/file_A.txt" > /dev/null 2>&1 &
    $SCRIPT delete "$TEST_DIR/file_B.txt" > /dev/null 2>&1 &
    wait

    PHYSICAL_FILES_COUNT=$(ls -1 ~/.recycle_bin/files | wc -l)
    METADATA_ENTRIES_COUNT=$(tail -n +2 ~/.recycle_bin/metadata.db | wc -l)

    if [ "$PHYSICAL_FILES_COUNT" -ne 2 ] || [ "$METADATA_ENTRIES_COUNT" -ne 2 ]; then
        echo "Inconsistency found: $PHYSICAL_FILES_COUNT physical files, $METADATA_ENTRIES_COUNT metadata entries."
        assert_success "Successfully demonstrated race condition vulnerability"
    else
        echo "Race condition not triggered this time (both operations succeeded)."
        assert_fail "Failed to demonstrate race condition vulnerability on this run"
    fi
}
test_performance_delete_110_files() {
    echo "=== Test: Performance - Delete 110 Files ==="
    setup
    for i in {1..110}; do
        echo "content $i" > "$TEST_DIR/file_$i.txt"
    done

    START_TIME=$(date +%s%N)
    $SCRIPT delete "$TEST_DIR/file_"*.txt > /dev/null 2>&1
    END_TIME=$(date +%s%N)

    DURATION=$((END_TIME - START_TIME))
    DURATION_MS=$((DURATION / 1000000))

    if [ $DURATION_MS -le 5000 ]; then #coloquei 5s como tempo maximo aceitável
        assert_success "Deleted 110 files in $DURATION_MS ms"
    else
        echo "Took too long: $DURATION_MS ms"
        assert_fail "Performance test failed: took too long to delete 110 files"
    fi
}
test_performance_list_110_files(){
    echo "=== Test: Performance - List 110 Files ==="
    setup
    for i in {1..110}; do
        echo "content $i" > "$TEST_DIR/file_$i.txt"
    done
    $SCRIPT delete "$TEST_DIR/file_"*.txt > /dev/null 2>&1

    START_TIME=$(date +%s%N)
    $SCRIPT list > /dev/null 2>&1
    END_TIME=$(date +%s%N)

    DURATION=$((END_TIME - START_TIME))
    DURATION_MS=$((DURATION / 1000000))

    if [ $DURATION_MS -le 2000 ]; then #coloquei 2s como tempo maximo aceitável
        assert_success "Listed 110 files in $DURATION_MS ms"
    else
        echo "Took too long: $DURATION_MS ms"
        assert_fail "Performance test failed: took too long to list 110 files"
    fi
}
test_search_in_large_metadata_file(){
    echo "=== Test: Search in Large Metadata ==="
    setup
    for i in {1..200}; do
        echo "file_$i.txt" > "$TEST_DIR/file_$i.txt"
        $SCRIPT delete "$TEST_DIR/file_$i.txt" > /dev/null 2>&1
    done

    START_TIME=$(date +%s%N)
    SEARCH_OUTPUT=$($SCRIPT search "file_150.txt")
    END_TIME=$(date +%s%N)

    DURATION=$((END_TIME - START_TIME))
    DURATION_MS=$((DURATION / 1000000))

    if echo "$SEARCH_OUTPUT" | grep -q "file_150.txt" && [ $DURATION_MS -le 3000 ]; then
        assert_success "Searched in large metadata in $DURATION_MS ms"
    else
        echo "Took too long or file not found: $DURATION_MS ms"
        assert_fail "Search in large metadata failed or took too long"
    fi
}
test_restore_from_bin_with_many_items(){
    echo "=== Test: Restore from Bin with Many Items ==="
    setup
    for i in {1..150}; do
        echo "file_$i.txt" > "$TEST_DIR/file_$i.txt"
        $SCRIPT delete "$TEST_DIR/file_$i.txt" > /dev/null 2>&1
    done

    ID=$($SCRIPT list | grep "file_75.txt" | awk '{print $1}')

    START_TIME=$(date +%s%N)
    $SCRIPT restore "$ID"
    END_TIME=$(date +%s%N)

    DURATION=$((END_TIME - START_TIME))
    DURATION_MS=$((DURATION / 1000000))

    if [ -f "$TEST_DIR/file_75.txt" ] && [ $DURATION_MS -le 4000 ]; then
        assert_success "Restored from bin with many items in $DURATION_MS ms"
    else
        echo "Took too long or file not restored: $DURATION_MS ms"
        assert_fail "Restore from bin with many items failed or took too long"
    fi
}

# Run all tests
echo "========================================="
echo " Recycle Bin Test Suite"
echo "========================================="
test_initialization
test_delete_file
test_list_empty
test_restore_file
test_delete_multiple_files
test_delete_empty_directory
test_delete_directory
test_list_with_files
test_restore_to_nonexistent_directory
test_empty_bin
test_search
test_search_nonexistent
test_help_command
test_delete_nonexistent_file
test_delete_file_without_permissions
test_restore_to_filename_conflict
test_restore_with_nonexistent_id
test_handle_filenames_with_spaces
test_handle_filenames_with_special_chars
test_handle_longnames
test_handle_large_files
test_handle_symbolic_links
test_handle_hidden_files
test_delete_from_multiple_directories
test_restore_to_readonly_directory
test_invalid_command
test_missing_parameters
test_delete_recycle_bin_itself
test_corrupted_metadata
test_error_insufficient_disk_space
test_error_permission_denied_on_delete
test_error_concurrent_operations
test_performance_delete_110_files
test_performance_list_110_files
test_search_in_large_metadata_file
test_restore_from_bin_with_many_items
# Add more test functions here
teardown
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="
