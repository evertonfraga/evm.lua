#!/bin/bash

# Source library functions
source ./lib.sh

# Test LOG1 opcode (0xA0)
test_log1() {
    local contract_addr="0x0000000000000000000000000000000000000080"
    # Store data in memory first, then emit LOG1
    # Bytecode: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 0x1234, PUSH1 1, PUSH1 0, LOG1, PUSH1 0x42, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 61 12 34 60 01 60 00 A0 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "LOG1 Test Passed: LOG1 executed successfully"
        return 0
    else
        fail "LOG1 Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test LOG2 opcode (0xA1)
test_log2() {
    local contract_addr="0x0000000000000000000000000000000000000081"
    # Store data in memory first, then emit LOG2
    # Bytecode: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 0x5678, PUSH1 0x1234, PUSH1 1, PUSH1 0, LOG2, PUSH1 0x42, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 61 56 78 61 12 34 60 01 60 00 A1 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "LOG2 Test Passed: LOG2 executed successfully"
        return 0
    else
        fail "LOG2 Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test LOG3 opcode (0xA2)
test_log3() {
    local contract_addr="0x0000000000000000000000000000000000000082"
    # Store data in memory first, then emit LOG3
    # Bytecode: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 0x9ABC, PUSH1 0x5678, PUSH1 0x1234, PUSH1 1, PUSH1 0, LOG3, PUSH1 0x42, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 61 9A BC 61 56 78 61 12 34 60 01 60 00 A2 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "LOG3 Test Passed: LOG3 executed successfully"
        return 0
    else
        fail "LOG3 Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test LOG4 opcode (0xA3)
test_log4() {
    local contract_addr="0x0000000000000000000000000000000000000083"
    # Store data in memory first, then emit LOG4
    # Bytecode: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 0xDEF0, PUSH1 0x9ABC, PUSH1 0x5678, PUSH1 0x1234, PUSH1 1, PUSH1 0, LOG4, PUSH1 0x42, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 61 DE F0 61 9A BC 61 56 78 61 12 34 60 01 60 00 A3 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "LOG4 Test Passed: LOG4 executed successfully"
        return 0
    else
        fail "LOG4 Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test LOG with empty data
test_log_empty() {
    local contract_addr="0x0000000000000000000000000000000000000084"
    # Emit LOG1 with no data
    # Bytecode: PUSH1 0x1234, PUSH1 0, PUSH1 0, LOG1, PUSH1 0x42, STOP
    redis-cli SET "$contract_addr" "61 12 34 60 00 60 00 A0 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "LOG Empty Test Passed: LOG with empty data executed successfully"
        return 0
    else
        fail "LOG Empty Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test LOG with multiple bytes of data
test_log_multiple_bytes() {
    local contract_addr="0x0000000000000000000000000000000000000085"
    # Store multiple bytes in memory, then emit LOG1
    # Bytecode: PUSH1 0x41, PUSH1 0, MSTORE8, PUSH1 0x42, PUSH1 1, MSTORE8, PUSH1 0x43, PUSH1 2, MSTORE8, PUSH1 0x1234, PUSH1 3, PUSH1 0, LOG1, PUSH1 0x42, STOP
    redis-cli SET "$contract_addr" "60 41 60 00 53 60 42 60 01 53 60 43 60 02 53 61 12 34 60 03 60 00 A0 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "LOG Multiple Bytes Test Passed: LOG with multiple bytes executed successfully"
        return 0
    else
        fail "LOG Multiple Bytes Test Failed" "0x42" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=6
    local passed_tests=0

    test_log1 && ((passed_tests++))
    test_log2 && ((passed_tests++))
    test_log3 && ((passed_tests++))
    test_log4 && ((passed_tests++))
    test_log_empty && ((passed_tests++))
    test_log_multiple_bytes && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Logging Tests Passed!"
        exit 0
    else
        fail "Some Logging Tests Failed"
        exit 1
    fi
}

# Run the main function
main