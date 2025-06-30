#!/bin/bash

# Source library functions
source ./lib.sh

# Function to parse debug output
parse_debug_output() {
    local debug_output="$1"
    
    # Extract PC value
    local pc=$(echo "$debug_output" | grep "^PC:" | cut -d' ' -f2)
    
    # Extract Stack section (line after "Stack" header until next empty line)
    local stack=$(echo "$debug_output" | awk '/^Stack$/{getline; print; exit}')
    
    # Extract Storage section (lines after "Storage" header until next empty line)
    local storage=$(echo "$debug_output" | awk '/^Storage$/,/^$/ {if(!/^Storage$/ && !/^$/) print}')
    
    # Extract Memory section (line after "Memory" header)
    local memory=$(echo "$debug_output" | awk '/^Memory$/{getline; print; exit}')

    # Print debug information
    echo "Program Counter: $pc"
    echo "Stack: $stack"
    echo "Storage:"
    echo "$storage"
    echo "Memory: $memory"
}

# Test ADD opcode (0x01)
test_add() {
    local contract_addr="0x0000000000000000000000000000000000000001"
    # Bytecode: PUSH1 10, PUSH1 20, ADD, STOP
    redis-cli SET "$contract_addr" "60 0A 60 14 01 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # parse_debug_output "$result"

    if [ "$result" = "0x1E" ]; then
        success "ADD Test Passed: 10 + 20 = 30 (0x1E)"
        return 0
    else
        fail "ADD Test Failed" "0x1E" "$result"
        return 1
    fi
}

# Test SUB opcode (0x03)
test_sub() {
    local contract_addr="0x0000000000000000000000000000000000000003"
    # Bytecode: PUSH1 10, PUSH1 25, SUB, STOP
    redis-cli SET "$contract_addr" "60 0A 60 19 03 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")

    if [ "$result" = "0x0F" ]; then
        success "SUB Test Passed: 25 - 10 = 15 (0x0F)"
        return 0
    else
        fail "SUB Test Failed" "0x0A" "$result"
        return 1
    fi
}

# Test MUL opcode (0x02)
test_mul() {
    local contract_addr="0x0000000000000000000000000000000000000002"
    # Bytecode: PUSH1 6, PUSH1 7, MUL, STOP
    redis-cli SET "$contract_addr" "60 06 60 07 02 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "MUL Test Passed: 6 * 7 = 42 ($result)"
        return 0
    else
        fail "MUL Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test DIV opcode (0x04)
test_div() {
    local contract_addr="0x0000000000000000000000000000000000000004"
    # Bytecode: PUSH1 5, PUSH1 20, DIV, STOP
    redis-cli SET "$contract_addr" "60 05 60 14 04 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")

    if [ "$result" = "0x04" ]; then
        success "DIV Test Passed: 20 / 5 = 4 ($result)"
        return 0
    else
        fail "DIV Test Failed" "0x04" "$result"
        return 1
    fi
}

# Test SDIV opcode (0x05)
test_sdiv() {
    local contract_addr="0x0000000000000000000000000000000000000005"
    # Bytecode: PUSH1 5, PUSH1 20, SDIV, STOP
    redis-cli SET "$contract_addr" "60 05 60 14 05 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")

    if [ "$result" = "0x04" ]; then
        success "SDIV Test Passed: 20 / 5 = 4 ($result)"
        return 0
    else
        fail "SDIV Test Failed" "0x04" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=5
    local passed_tests=0

    test_add && ((passed_tests++))
    test_sub && ((passed_tests++))
    test_mul && ((passed_tests++))
    test_div && ((passed_tests++))
    test_sdiv && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Arithmetic Opcode Tests Passed!"
        exit 0
    else
        fail "Some Arithmetic Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main
