#!/usr/bin/env bash
#
# Test script for restore.sh
# Tests basic functionality without requiring actual Docker volumes

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

# Function to display test summary
display_summary() {
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total tests: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "=========================================="
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        print_success "All tests passed!"
        exit 0
    else
        print_error "Some tests failed!"
        exit 1
    fi
}

# Main test execution
main() {
    echo "Testing restore.sh script..."
    echo ""
    
    # Test 1: Script exists and is readable
    run_test "Script exists and is readable" \
        "[ -r '$SCRIPT_DIR/restore.sh' ]"
    
    # Test 2: Help option works
    run_test "Help option displays usage" \
        "bash '$SCRIPT_DIR/restore.sh' --help"
    
    # Test 3: No arguments shows error
    run_test "No arguments returns error" \
        "bash '$SCRIPT_DIR/restore.sh'" \
        1
    
    # Test 4: Invalid option shows error
    run_test "Invalid option returns error" \
        "bash '$SCRIPT_DIR/restore.sh' --invalid-option" \
        1
    
    # Test 5: Non-existent backup file shows error
    run_test "Non-existent backup file returns error" \
        "bash '$SCRIPT_DIR/restore.sh' --force nonexistent_backup.tar.gz" \
        1
    
    # Test 6: Script has proper shebang
    run_test "Script has proper shebang" \
        "head -n 1 '$SCRIPT_DIR/restore.sh' | grep -q '^#!/usr/bin/env bash'"
    
    # Test 7: Script uses set -e for error handling
    run_test "Script uses set -e" \
        "grep -q '^set -e' '$SCRIPT_DIR/restore.sh'"
    
    # Test 8: Script has main function
    run_test "Script has main function" \
        "grep -q '^main()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 9: Script has verify_backup_integrity function
    run_test "Script has verify_backup_integrity function" \
        "grep -q '^verify_backup_integrity()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 10: Script has restore_db_volume function
    run_test "Script has restore_db_volume function" \
        "grep -q '^restore_db_volume()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 11: Script has restore_storage_volume function
    run_test "Script has restore_storage_volume function" \
        "grep -q '^restore_storage_volume()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 12: Script has error handling functions
    run_test "Script has print_error function" \
        "grep -q '^print_error()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 13: Script checks Docker daemon
    run_test "Script has check_docker function" \
        "grep -q '^check_docker()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 14: Script checks docker-compose
    run_test "Script has check_docker_compose function" \
        "grep -q '^check_docker_compose()' '$SCRIPT_DIR/restore.sh'"
    
    # Test 15: Script has confirmation prompt
    run_test "Script has confirm_restore function" \
        "grep -q '^confirm_restore()' '$SCRIPT_DIR/restore.sh'"
    
    # Display summary
    display_summary
}

# Run tests
main "$@"
