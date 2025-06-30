#!/bin/bash

# Source library functions
source ./lib.sh

# ANSI color codes for better output
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to run a test suite and capture results
run_test_suite() {
    local test_file="$1"
    local suite_name="$2"
    
    echo -e "${BLUE}${BOLD}Running $suite_name Tests...${NC}"
    echo "=================================================="
    
    if [ -f "$test_file" ]; then
        chmod +x "$test_file"
        if ./"$test_file"; then
            echo -e "${GREEN}✓ $suite_name Test Suite PASSED${NC}"
            echo ""
            return 0
        else
            echo -e "${RED}✗ $suite_name Test Suite FAILED${NC}"
            echo ""
            return 1
        fi
    else
        echo -e "${RED}✗ Test file $test_file not found${NC}"
        echo ""
        return 1
    fi
}

# Function to display summary
display_summary() {
    local total_suites="$1"
    local passed_suites="$2"
    local failed_suites="$3"
    
    echo ""
    echo "=================================================="
    echo -e "${BOLD}${CYAN}TEST SUMMARY${NC}"
    echo "=================================================="
    echo "Total Test Suites: $total_suites"
    echo -e "${GREEN}Passed: $passed_suites${NC}"
    echo -e "${RED}Failed: $failed_suites${NC}"
    
    if [ $passed_suites -eq $total_suites ]; then
        echo ""
        echo -e "${GREEN}${BOLD}🎉 ALL TEST SUITES PASSED! 🎉${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}${BOLD}❌ SOME TEST SUITES FAILED ❌${NC}"
        return 1
    fi
}

# Main test runner
main() {
    echo -e "${CYAN}${BOLD}EVM Redis Implementation - Comprehensive Test Suite${NC}"
    echo "=================================================="
    echo ""
    
    # Ensure Redis is running and EVM function is loaded
    ensure_redis_running
    load_evm_function
    
    local total_suites=11
    local passed_suites=0
    local failed_suites=0
    
    # Array of test suites
    declare -a test_suites=(
        "test-arithmetic.sh:Arithmetic Operations"
        "test-comparison.sh:Comparison Operations"
        "test-stack.sh:Stack and Memory Operations"
        "test-control-flow.sh:Control Flow Operations"
        "test-storage.sh:Storage Operations"
        "test-keccak.sh:KECCAK256 Hash Operations"
        "test-memory.sh:Memory Operations"
        "test-bitwise.sh:Bitwise Operations"
        "test-blockchain-context.sh:Blockchain Context"
        "test-logging.sh:Logging Operations"
        "test-calldata.sh:Calldata Operations"
    )
    
    # Run each test suite
    for suite in "${test_suites[@]}"; do
        IFS=':' read -r test_file suite_name <<< "$suite"
        
        if run_test_suite "$test_file" "$suite_name"; then
            ((passed_suites++))
        else
            ((failed_suites++))
        fi
    done
    
    # Display final summary
    display_summary $total_suites $passed_suites $failed_suites
    
    # Exit with appropriate code
    if [ $passed_suites -eq $total_suites ]; then
        exit 0
    else
        exit 1
    fi
}

# Run the main function
main
