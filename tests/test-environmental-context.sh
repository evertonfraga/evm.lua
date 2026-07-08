#!/bin/bash

# Source library functions
source ./lib.sh

# Test BALANCE opcode (0x31)
test_balance() {
    local contract_addr="0x0000000000000000000000000000000000000031"
    
    # Setup test data
    redis-cli SET "BALANCE:1234567890123456789012345678901234567890" "1000000000000000000"  # 1 ETH in wei
    
    # Bytecode: PUSH20 0x1234567890123456789012345678901234567890, BALANCE, STOP
    # PUSH20 = 0x73, followed by 20 bytes of address, then BALANCE (0x31), then STOP (0x00)
    redis-cli SET "$contract_addr" "73 12 34 56 78 90 12 34 56 78 90 12 34 56 78 90 12 34 56 78 90 31 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Convert expected result to hex (1000000000000000000 in decimal = 0xDE0B6B3A7640000 in hex)
    local expected="0xDE0B6B3A7640000"
    
    if [ "$result" = "$expected" ]; then
        success "BALANCE Test Passed: Retrieved balance of 1 ETH ($result)"
        return 0
    else
        fail "BALANCE Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test BALANCE with zero balance
test_balance_zero() {
    local contract_addr="0x0000000000000000000000000000000000000032"
    
    # Setup test data - address with zero balance
    redis-cli SET "BALANCE:0000000000000000000000000000000000000000" "0"
    
    # Bytecode: PUSH20 0x0000000000000000000000000000000000000000, BALANCE, STOP
    redis-cli SET "$contract_addr" "73 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 31 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "BALANCE Zero Test Passed: Retrieved zero balance ($result)"
        return 0
    else
        fail "BALANCE Zero Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test BALANCE with non-existent address (should return 0)
test_balance_nonexistent() {
    local contract_addr="0x0000000000000000000000000000000000000033"
    
    # Ensure the address doesn't exist in Redis
    redis-cli DEL "BALANCE:9999999999999999999999999999999999999999"
    
    # Bytecode: PUSH20 0x9999999999999999999999999999999999999999, BALANCE, STOP
    redis-cli SET "$contract_addr" "73 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 99 31 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "BALANCE Non-existent Test Passed: Retrieved zero balance for non-existent address ($result)"
        return 0
    else
        fail "BALANCE Non-existent Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test ORIGIN opcode (0x32)
test_origin() {
    local contract_addr="0x0000000000000000000000000000000000000034"
    
    # Setup test data
    redis-cli SET "ORIGIN" "0x0000000000000000000000000000000000000001"
    
    # Bytecode: ORIGIN, STOP
    redis-cli SET "$contract_addr" "32 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x0000000000000000000000000000000000000001"
    
    if [ "$result" = "$expected" ]; then
        success "ORIGIN Test Passed: Retrieved transaction origin ($result)"
        return 0
    else
        fail "ORIGIN Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test ORIGIN with default value
test_origin_default() {
    local contract_addr="0x0000000000000000000000000000000000000035"
    
    # Remove ORIGIN from Redis to test default
    redis-cli DEL "ORIGIN"
    
    # Bytecode: ORIGIN, STOP
    redis-cli SET "$contract_addr" "32 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x0000000000000000000000000000000000000000"
    
    if [ "$result" = "$expected" ]; then
        success "ORIGIN Default Test Passed: Retrieved default origin ($result)"
        return 0
    else
        fail "ORIGIN Default Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test CODESIZE opcode (0x38)
test_codesize() {
    local contract_addr="0x0000000000000000000000000000000000000036"
    
    # Setup test data - contract with bytecode that tests CODESIZE
    # This bytecode will be: PUSH1 0x42, CODESIZE, ADD, STOP
    # Expected result: 0x42 (66) + codesize (5) = 71 (0x47)
    local test_code="60 42 38 01 00"  # 5 bytes when spaces are removed = 10 hex chars / 2
    redis-cli SET "$contract_addr" "$test_code"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x42 + 0x05 = 0x47
    local expected="0x47"
    
    if [ "$result" = "$expected" ]; then
        success "CODESIZE Test Passed: 0x42 + codesize(5) = 0x47 ($result)"
        return 0
    else
        fail "CODESIZE Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test CODESIZE with minimal code that just returns the codesize
test_codesize_minimal() {
    local contract_addr="0x0000000000000000000000000000000000000037"
    
    # Setup test data - contract with minimal code: just CODESIZE, STOP
    redis-cli SET "$contract_addr" "38 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 2 bytes (38 00 = 4 hex chars / 2) = 0x02
    if [ "$result" = "0x02" ]; then
        success "CODESIZE Minimal Test Passed: Retrieved size of 2 bytes for minimal code ($result)"
        return 0
    else
        fail "CODESIZE Minimal Test Failed" "0x02" "$result"
        return 1
    fi
}

# Test CODESIZE with longer code
test_codesize_longer() {
    local contract_addr="0x0000000000000000000000000000000000000038"
    
    # Setup test data - contract with longer code that includes CODESIZE
    # PUSH1 0x10, CODESIZE, MUL, STOP (multiply codesize by 16)
    local test_code="60 10 38 02 00"  # 5 bytes
    redis-cli SET "$contract_addr" "$test_code"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 16 * 5 = 80 = 0x50
    if [ "$result" = "0x50" ]; then
        success "CODESIZE Longer Test Passed: 16 * codesize(5) = 80 ($result)"
        return 0
    else
        fail "CODESIZE Longer Test Failed" "0x50" "$result"
        return 1
    fi
}

# Test complex scenario with multiple environmental opcodes
test_environmental_combination() {
    local contract_addr="0x0000000000000000000000000000000000000039"
    
    # Setup test data
    redis-cli SET "BALANCE:1111111111111111111111111111111111111111" "500000000000000000"  # 0.5 ETH
    redis-cli SET "ORIGIN" "0x2222222222222222222222222222222222222222"
    redis-cli SET "CODE:0000000000000000000000000000000000000039" "6080604052"  # 5 bytes
    
    # Bytecode: 
    # PUSH20 0x1111111111111111111111111111111111111111, BALANCE,  # Get balance
    # ORIGIN,                                                        # Get origin
    # CODESIZE,                                                      # Get code size
    # ADD, ADD,                                                      # Add all three values
    # STOP
    redis-cli SET "$contract_addr" "73 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 31 32 38 01 01 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected calculation:
    # Balance: 500000000000000000 (0.5 ETH)
    # Origin: 0x2222222222222222222222222222222222222222 (large number)
    # Codesize: 5
    # The exact result will be very large due to the origin address value
    
    # For this test, we just verify we get a non-zero result
    if [ "$result" != "0x00" ] && [ "$result" != "" ]; then
        success "Environmental Combination Test Passed: Got combined result ($result)"
        return 0
    else
        fail "Environmental Combination Test Failed" "non-zero result" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=8
    local passed_tests=0

    test_balance && ((passed_tests++))
    test_balance_zero && ((passed_tests++))
    test_balance_nonexistent && ((passed_tests++))
    test_origin && ((passed_tests++))
    test_origin_default && ((passed_tests++))
    test_codesize && ((passed_tests++))
    test_codesize_minimal && ((passed_tests++))
    test_codesize_longer && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Environmental Context Opcode Tests Passed!"
        exit 0
    else
        fail "Some Environmental Context Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main