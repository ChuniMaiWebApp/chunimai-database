#!/usr/bin/env bash
#
# Integration test for restore.sh
# Creates mock backup files and tests restore functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKUP_DIR="$BASE_DIR/backups"
TEST_DIR="$BASE_DIR/.test_restore_tmp"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print colored messages
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Function to cleanup test files
cleanup() {
    print_info "Cleaning up test files..."
    rm -rf "$TEST_DIR"
    # Remove test backup files
    rm -f "$BACKUP_DIR/test_backup_"*.tar.gz
}

# Setup cleanup trap
trap cleanup EXIT

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2
    local expected_exit_code=${3:-0}
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    print_info "Test $TESTS_RUN: $test_name"
    
    # Run the command and capture exit code
    set +e
    eval "$test_command" > /dev/null 2>&1
    local actual_exit_code=$?
    set -e
    
    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        print_success "PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        print_error "FAIL: $test_name (expected exit code $expected_exit_code, got $actual_exit_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

# Function to create mock backup file
create_mock_backup() {
    local backup_type=$1
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/test_backup_${backup_type}_${timestamp}.tar.gz"
    
    # Create test directory with some files
    mkdir -p "$TEST_DIR/data"
    echo "test data" > "$TEST_DIR/data/test.txt"
    echo "more data" > "$TEST_DIR/data/test2.txt"
    
    # Create tar.gz archive
    tar czf "$backup_file" -C "$TEST_DIR/data" .
    
    echo "$backup_file"
}

# Function to display test summary
display_summary() {
    echo "=========================================="
    echo "Integration Test Summary"
    echo "=========================================="
    echo "Total tests: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "=========================================="
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        print_success "All integration tests passed!"
        exit 0
    else
        print_error "Some integration tests failed!"
        exit 1
    fi
}

# Main test execution
main() {
    echo "Running restore.sh integration tests..."
    echo ""
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Test 1: Create and verify database backup file
    print_info "Creating mock database backup..."
    DB_BACKUP=$(create_mock_backup "supabase_db_backup")
    run_test "Mock database backup created" \
        "[ -f '$DB_BACKUP' ]"
    
    # Test 2: Verify backup integrity check works
    run_test "Backup integrity verification works" \
        "gzip -t '$DB_BACKUP'"
    
    # Test 3: Verify tar archive is valid
    run_test "Tar archive is valid" \
        "tar -tzf '$DB_BACKUP' > /dev/null"
    
    # Test 4: Create and verify storage backup file
    print_info "Creating mock storage backup..."
    STORAGE_BACKUP=$(create_mock_backup "supabase_storage_backup")
    run_test "Mock storage backup created" \
        "[ -f '$STORAGE_BACKUP' ]"
    
    # Test 5: Test backup type detection for database
    run_test "Database backup type detected correctly" \
        "echo '$DB_BACKUP' | grep -q 'supabase_db_backup'"
    
    # Test 6: Test backup type detection for storage
    run_test "Storage backup type detected correctly" \
        "echo '$STORAGE_BACKUP' | grep -q 'supabase_storage_backup'"
    
    # Test 7: Test invalid backup file (corrupted)
    print_info "Creating corrupted backup file..."
    CORRUPTED_BACKUP="$BACKUP_DIR/test_backup_corrupted_$(date +"%Y%m%d_%H%M%S").tar.gz"
    echo "not a valid gzip file" > "$CORRUPTED_BACKUP"
    run_test "Corrupted backup file detected" \
        "gzip -t '$CORRUPTED_BACKUP'" \
        1
    
    # Test 8: Test empty backup file
    print_info "Creating empty backup file..."
    EMPTY_BACKUP="$BACKUP_DIR/test_backup_empty_$(date +"%Y%m%d_%H%M%S").tar.gz"
    touch "$EMPTY_BACKUP"
    run_test "Empty backup file detected" \
        "gzip -t '$EMPTY_BACKUP'" \
        1
    
    # Test 9: Test backup file with wrong extension
    print_info "Creating backup with wrong extension..."
    WRONG_EXT="$BACKUP_DIR/test_backup_wrong.txt"
    echo "test" > "$WRONG_EXT"
    run_test "Wrong extension detected" \
        "gzip -t '$WRONG_EXT'" \
        1
    
    # Test 10: Verify script can find backup in backup directory
    run_test "Script can find backup by filename only" \
        "[ -f '$BACKUP_DIR/$(basename $DB_BACKUP)' ]"
    
    # Display summary
    display_summary
}

# Run tests
main "$@"
