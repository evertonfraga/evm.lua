#!/bin/bash

# Source library functions
source ./lib.sh

# Test AND opcode (0x16)
test_and() {
    local contract_addr="0x0000000000000000000000000000000000000060"
    # Bytecode: PUSH1 0x0F, PUSH1 0x33, AND, STOP (15 & 51 = 3)
    redis-cli SET "$contract_addr" "60 0F 60 33 16 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x03" ]; then
        success "AND Test Passed: 0x0F & 0x33 = 0x03"
        return 0
    else
        fail "AND Test Failed" "0x03" "$result"
        return 1
    fi
}

# Test OR opcode (0x17)
test_or() {
    local contract_addr="0x0000000000000000000000000000000000000061"
    # Bytecode: PUSH1 0x0F, PUSH1 0x30, OR, STOP (15 | 48 = 63)
    redis-cli SET "$contract_addr" "60 0F 60 30 17 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x3F" ]; then
        success "OR Test Passed: 0x0F | 0x30 = 0x3F"
        return 0
    else
        fail "OR Test Failed" "0x3F" "$result"
        return 1
    fi
}

# Test NOT opcode (0x19)
test_not() {
    local contract_addr="0x0000000000000000000000000000000000000062"
    # Bytecode: PUSH1 0x00, NOT, STOP
    redis-cli SET "$contract_addr" "60 00 19 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # NOT 0 should give max value
    if [[ "$result" =~ ^0x[1-9A-F] ]]; then
        success "NOT Test Passed: NOT(0) = $result"
        return 0
    else
        fail "NOT Test Failed" "non-zero value" "$result"
        return 1
    fi
}

# Test SHR opcode (0x1C)
test_shr() {
    local contract_addr="0x0000000000000000000000000000000000000063"
    # Bytecode: PUSH1 2, PUSH1 8, SHR, STOP (8 >> 2 = 2)
    redis-cli SET "$contract_addr" "60 02 60 08 1C 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x02" ]; then
        success "SHR Test Passed: 8 >> 2 = 2"
        return 0
    else
        fail "SHR Test Failed" "0x02" "$result"
        return 1
    fi
}

# Test EXP opcode (0x0A)
test_exp() {
    local contract_addr="0x0000000000000000000000000000000000000064"
    # Bytecode: PUSH1 3, PUSH1 2, EXP, STOP (2^3 = 8)
    redis-cli SET "$contract_addr" "60 03 60 02 0A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x08" ]; then
        success "EXP Test Passed: 2^3 = 8"
        return 0
    else
        fail "EXP Test Failed" "0x08" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=5
    local passed_tests=0

    test_and && ((passed_tests++))
    test_or && ((passed_tests++))
    test_not && ((passed_tests++))
    test_shr && ((passed_tests++))
    test_exp && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Bitwise Operation Tests Passed!"
        exit 0
    else
        fail "Some Bitwise Operation Tests Failed"
        exit 1
    fi
}

# Run the main function
main