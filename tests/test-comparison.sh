#!/bin/bash

# Source library functions
source ./lib.sh

# Test LT opcode (0x10) - Less Than
test_lt() {
    local contract_addr="0x0000000000000000000000000000000000000010"
    # Bytecode: PUSH1 5, PUSH1 10, LT, STOP (5 < 10 should return 1)
    redis-cli SET "$contract_addr" "60 05 60 0A 10 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "LT Test 1 Passed: 5 < 10 = true (0x01)"
    else
        fail "LT Test 1 Failed" "0x01" "$result"
        return 1
    fi

    # Test case where LT should return false
    local contract_addr2="0x0000000000000000000000000000000000000011"
    # Bytecode: PUSH1 15, PUSH1 10, LT, STOP (15 < 10 should return 0)
    redis-cli SET "$contract_addr2" "60 0F 60 0A 10 00"
    
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result2" = "0x00" ]; then
        success "LT Test 2 Passed: 15 < 10 = false (0x00)"
        return 0
    else
        fail "LT Test 2 Failed" "0x00" "$result2"
        return 1
    fi
}

# Test GT opcode (0x11) - Greater Than
test_gt() {
    local contract_addr="0x0000000000000000000000000000000000000012"
    # Bytecode: PUSH1 15, PUSH1 10, GT, STOP (15 > 10 should return 1)
    redis-cli SET "$contract_addr" "60 0F 60 0A 11 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "GT Test 1 Passed: 15 > 10 = true (0x01)"
    else
        fail "GT Test 1 Failed" "0x01" "$result"
        return 1
    fi

    # Test case where GT should return false
    local contract_addr2="0x0000000000000000000000000000000000000013"
    # Bytecode: PUSH1 5, PUSH1 10, GT, STOP (5 > 10 should return 0)
    redis-cli SET "$contract_addr2" "60 05 60 0A 11 00"
    
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result2" = "0x00" ]; then
        success "GT Test 2 Passed: 5 > 10 = false (0x00)"
        return 0
    else
        fail "GT Test 2 Failed" "0x00" "$result2"
        return 1
    fi
}

# Test SLT opcode (0x12) - Signed Less Than
test_slt() {
    local contract_addr="0x0000000000000000000000000000000000000014"
    # Bytecode: PUSH1 5, PUSH1 10, SLT, STOP (5 < 10 should return 1)
    redis-cli SET "$contract_addr" "60 05 60 0A 12 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "SLT Test Passed: 5 < 10 = true (0x01)"
        return 0
    else
        fail "SLT Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SGT opcode (0x13) - Signed Greater Than
test_sgt() {
    local contract_addr="0x0000000000000000000000000000000000000015"
    # Bytecode: PUSH1 15, PUSH1 10, SGT, STOP (15 > 10 should return 1)
    redis-cli SET "$contract_addr" "60 0F 60 0A 13 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "SGT Test Passed: 15 > 10 = true (0x01)"
        return 0
    else
        fail "SGT Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test EQ opcode (0x14) - Equal
test_eq() {
    local contract_addr="0x0000000000000000000000000000000000000016"
    # Bytecode: PUSH1 10, PUSH1 10, EQ, STOP (10 == 10 should return 1)
    redis-cli SET "$contract_addr" "60 0A 60 0A 14 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "EQ Test 1 Passed: 10 == 10 = true (0x01)"
    else
        fail "EQ Test 1 Failed" "0x01" "$result"
        return 1
    fi

    # Test case where EQ should return false
    local contract_addr2="0x0000000000000000000000000000000000000017"
    # Bytecode: PUSH1 5, PUSH1 10, EQ, STOP (5 == 10 should return 0)
    redis-cli SET "$contract_addr2" "60 05 60 0A 14 00"
    
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result2" = "0x00" ]; then
        success "EQ Test 2 Passed: 5 == 10 = false (0x00)"
        return 0
    else
        fail "EQ Test 2 Failed" "0x00" "$result2"
        return 1
    fi
}

# Test ISZERO opcode (0x15)
test_iszero() {
    local contract_addr="0x0000000000000000000000000000000000000018"
    # Bytecode: PUSH1 0, ISZERO, STOP (0 == 0 should return 1)
    redis-cli SET "$contract_addr" "60 00 15 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "ISZERO Test 1 Passed: ISZERO(0) = true (0x01)"
    else
        fail "ISZERO Test 1 Failed" "0x01" "$result"
        return 1
    fi

    # Test case where ISZERO should return false
    local contract_addr2="0x0000000000000000000000000000000000000019"
    # Bytecode: PUSH1 5, ISZERO, STOP (5 != 0 should return 0)
    redis-cli SET "$contract_addr2" "60 05 15 00"
    
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result2" = "0x00" ]; then
        success "ISZERO Test 2 Passed: ISZERO(5) = false (0x00)"
        return 0
    else
        fail "ISZERO Test 2 Failed" "0x00" "$result2"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=6
    local passed_tests=0

    test_lt && ((passed_tests++))
    test_gt && ((passed_tests++))
    test_slt && ((passed_tests++))
    test_sgt && ((passed_tests++))
    test_eq && ((passed_tests++))
    test_iszero && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Comparison Opcode Tests Passed!"
        exit 0
    else
        fail "Some Comparison Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main
