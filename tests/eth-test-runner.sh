#!/bin/bash

# Ethereum Foundation Test Runner for EVM.lua
# This script runs official Ethereum GeneralStateTests against the EVM implementation

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library functions
source "$SCRIPT_DIR/lib.sh"

# Configuration
ETH_TESTS_DIR="../ethereum-tests"
EXTRACTED_TESTS_DIR="/tmp/GeneralStateTests"
TEST_RESULTS_DIR="./eth-test-results"

# Extract tests if not already extracted
extract_tests() {
    if [ ! -d "$EXTRACTED_TESTS_DIR" ]; then
        echo "Extracting Ethereum Foundation tests..."
        tar -xzf "$ETH_TESTS_DIR/fixtures_general_state_tests.tgz" -C /tmp
        success "Tests extracted to $EXTRACTED_TESTS_DIR"
    else
        echo "Tests already extracted at $EXTRACTED_TESTS_DIR"
    fi
}

# Parse a single test case from JSON
# Arguments: test_file test_name
run_single_test() {
    local test_file="$1"
    local test_name="$2"
    
    # Use jq to parse the test JSON
    # Extract: pre-state, transaction, post-state expectations
    local test_data=$(cat "$test_file" | python3 -c "
import json
import sys

data = json.load(sys.stdin)
# Get the first test case (tests can have multiple variants)
test_key = list(data.keys())[0]
test = data[test_key]

# Extract pre-state accounts
pre = test.get('pre', {})
# Extract transaction data
tx = test.get('transaction', {})
# Extract environment
env = test.get('env', {})
# Extract post-state for different forks
post = test.get('post', {})

print(json.dumps({
    'pre': pre,
    'transaction': tx,
    'env': env,
    'post': post
}))
")
    
    echo "$test_data"
}

# Setup pre-state in Redis
setup_prestate() {
    local prestate="$1"
    
    # Parse and load each account into Redis
    echo "$prestate" | python3 -c "
import json
import sys
import subprocess

pre = json.load(sys.stdin)

for address, account in pre.items():
    # Set contract code if exists
    code = account.get('code', '0x')
    if code and code != '0x':
        # Remove 0x prefix and format for Redis
        code_bytes = code[2:] if code.startswith('0x') else code
        subprocess.run(['redis-cli', 'SET', address, code_bytes])
    
    # Set storage values
    storage = account.get('storage', {})
    for key, value in storage.items():
        storage_key = f'{address}:storage:{key}'
        subprocess.run(['redis-cli', 'SET', storage_key, value])
    
    # Set balance
    balance = account.get('balance', '0x0')
    balance_key = f'{address}:balance'
    subprocess.run(['redis-cli', 'SET', balance_key, balance])
    
    # Set nonce
    nonce = account.get('nonce', '0x0')
    nonce_key = f'{address}:nonce'
    subprocess.run(['redis-cli', 'SET', nonce_key, nonce])
"
}

# Run a test category
run_test_category() {
    local category="$1"
    local test_dir="$EXTRACTED_TESTS_DIR/$category"
    
    if [ ! -d "$test_dir" ]; then
        echo "Test category not found: $category"
        return 1
    fi
    
    echo "Running tests from category: $category"
    
    local total=0
    local passed=0
    local failed=0
    
    # Find all JSON test files
    for test_file in "$test_dir"/*.json; do
        if [ -f "$test_file" ]; then
            local test_name=$(basename "$test_file" .json)
            echo "  Testing: $test_name"
            
            # TODO: Implement actual test execution
            # For now, just count the test
            ((total++))
        fi
    done
    
    echo "Category $category: $total tests found"
}

# List available test categories
list_categories() {
    echo "Available test categories:"
    if [ -d "$EXTRACTED_TESTS_DIR" ]; then
        ls -1 "$EXTRACTED_TESTS_DIR" | grep -v "\.json$"
    else
        echo "Tests not extracted yet. Run with 'extract' command first."
    fi
}

# Run tests for implemented opcodes
run_implemented_tests() {
    echo "Running tests for implemented opcodes..."
    
    local total_categories=0
    local found_categories=0
    
    # Stack tests - we have full stack implementation
    if run_test_category "stStackTests"; then
        ((found_categories++))
    fi
    ((total_categories++))
    
    # Memory tests
    if run_test_category "stMemoryTest"; then
        ((found_categories++))
    fi
    ((total_categories++))
    
    # Storage tests
    if run_test_category "stSStoreTest"; then
        ((found_categories++))
    fi
    ((total_categories++))
    
    # Log tests
    if run_test_category "stLogTests"; then
        ((found_categories++))
    fi
    ((total_categories++))
    
    echo ""
    echo "Summary: Found $found_categories/$total_categories test categories"
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        extract)
            extract_tests
            ;;
        list)
            list_categories
            ;;
        category)
            if [ -z "$2" ]; then
                echo "Usage: $0 category <category_name>"
                exit 1
            fi
            extract_tests
            run_test_category "$2"
            ;;
        implemented)
            extract_tests
            run_implemented_tests
            ;;
        help|*)
            echo "Ethereum Foundation Test Runner"
            echo ""
            echo "Usage: $0 <command> [options]"
            echo ""
            echo "Commands:"
            echo "  extract       Extract test files from archive"
            echo "  list          List available test categories"
            echo "  category <name>  Run tests from specific category"
            echo "  implemented   Run tests for implemented opcodes"
            echo "  help          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 extract"
            echo "  $0 list"
            echo "  $0 category stStackTests"
            echo "  $0 implemented"
            ;;
    esac
}

# Run main
main "$@"
