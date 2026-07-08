#!/bin/bash

# Source library functions
source ./lib.sh

# Test EXTCODESIZE opcode (0x3B)
test_extcodesize() {
    local contract_addr="0x0000000000000000000000000000000000000090"
    local external_addr="0x1111111111111111111111111111111111111111"
    
    # Set up external contract with some bytecode (10 bytes = 20 hex chars)
    redis-cli SET "CODE:$external_addr" "60 42 60 00 53 60 42 00 60 00"
    
    # Bytecode: PUSH20 external_addr, EXTCODESIZE, STOP
    # This pushes the external address and gets its code size
    redis-cli SET "$contract_addr" "73 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 11 3B 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 10 bytes (0x0A)
    if [ "$result" = "0x0A" ]; then
        success "EXTCODESIZE Test Passed: External contract code size = 10 bytes"
        return 0
    else
        fail "EXTCODESIZE Test Failed" "0x0A" "$result"
        return 1
    fi
}

# Test EXTCODESIZE with empty contract
test_extcodesize_empty() {
    local contract_addr="0x0000000000000000000000000000000000000091"
    local external_addr="0x2222222222222222222222222222222222222222"
    
    # Don't set any code for external address (empty contract)
    
    # Bytecode: PUSH20 external_addr, EXTCODESIZE, STOP
    redis-cli SET "$contract_addr" "73 22 22 22 22 22 22 22 22 22 22 22 22 22 22 22 22 22 22 22 22 3B 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0 bytes for empty contract
    if [ "$result" = "0x00" ]; then
        success "EXTCODESIZE Empty Test Passed: Empty contract code size = 0"
        return 0
    else
        fail "EXTCODESIZE Empty Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test EXTCODECOPY opcode (0x3C)
test_extcodecopy() {
    local contract_addr="0x0000000000000000000000000000000000000092"
    local external_addr="0x3333333333333333333333333333333333333333"
    
    # Set up external contract with simple bytecode: PUSH1 0x42, STOP (3 bytes)
    redis-cli SET "CODE:$external_addr" "60 42 00"
    
    # Simpler test: just copy and return a simple value
    # Bytecode: PUSH1 1 (length), PUSH1 0 (code_offset), PUSH1 0 (dest_offset), PUSH20 external_addr, EXTCODECOPY, PUSH1 0x42, STOP
    # This copies 1 byte from external contract to memory, then returns 0x42 to verify the operation completed
    redis-cli SET "$contract_addr" "60 01 60 00 60 00 73 33 33 33 33 33 33 33 33 33 33 33 33 33 33 33 33 33 33 33 33 3C 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x42 (just to verify the operation completed successfully)
    local expected="0x42"
    if [ "$result" = "$expected" ]; then
        success "EXTCODECOPY Test Passed: EXTCODECOPY operation completed"
        return 0
    else
        fail "EXTCODECOPY Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test EXTCODECOPY with memory verification
test_extcodecopy_bounds() {
    local contract_addr="0x0000000000000000000000000000000000000093"
    local external_addr="0x4444444444444444444444444444444444444444"
    
    # Set up external contract with bytecode: PUSH1 0x42, STOP (3 bytes)
    redis-cli SET "CODE:$external_addr" "60 42 00"
    
    # Copy code to memory and then load it back
    # Bytecode: PUSH1 3 (length), PUSH1 0 (code_offset), PUSH1 0 (dest_offset), PUSH20 external_addr, EXTCODECOPY, PUSH1 0, MLOAD, STOP
    redis-cli SET "$contract_addr" "60 03 60 00 60 00 73 44 44 44 44 44 44 44 44 44 44 44 44 44 44 44 44 44 44 44 44 3C 60 00 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x6042000000000000000000000000000000000000000000000000000000000000 (3 bytes of code + 29 bytes of padding)
    local expected="0x6042000000000000000000000000000000000000000000000000000000000000"

    if [ "$result" = "$expected" ]; then
        success "EXTCODECOPY Memory Test Passed: Properly copied and loaded from memory"
        return 0
    else
        fail "EXTCODECOPY Memory Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test EXTCODEHASH opcode (0x3F)
test_extcodehash() {
    local contract_addr="0x0000000000000000000000000000000000000094"
    local external_addr="0x5555555555555555555555555555555555555555"
    
    # Set up external contract with known bytecode
    redis-cli SET "CODE:$external_addr" "60 42 00"  # PUSH1 0x42, STOP
    
    # Bytecode: PUSH20 external_addr, EXTCODEHASH, STOP
    redis-cli SET "$contract_addr" "73 55 55 55 55 55 55 55 55 55 55 55 55 55 55 55 55 55 55 55 55 3F 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # The result should be a 32-byte hash (66 chars: 0x + 64 hex chars)
    if [[ "$result" =~ ^0x[0-9A-Fa-f]{64}$ ]]; then
        success "EXTCODEHASH Test Passed: Generated valid code hash"
        return 0
    else
        fail "EXTCODEHASH Test Failed" "32-byte hash" "$result"
        return 1
    fi
}

# Test EXTCODEHASH with empty contract
test_extcodehash_empty() {
    local contract_addr="0x0000000000000000000000000000000000000095"
    local external_addr="0x6666666666666666666666666666666666666666"
    
    # Don't set any code for external address (empty contract)
    
    # Bytecode: PUSH20 external_addr, EXTCODEHASH, STOP
    redis-cli SET "$contract_addr" "73 66 66 66 66 66 66 66 66 66 66 66 66 66 66 66 66 66 66 66 66 3F 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0 for empty contract
    if [ "$result" = "0x00" ]; then
        success "EXTCODEHASH Empty Test Passed: Empty contract returns 0"
        return 0
    else
        fail "EXTCODEHASH Empty Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test EXTCODEHASH caching
test_extcodehash_caching() {
    local contract_addr="0x0000000000000000000000000000000000000096"
    local external_addr="0x7777777777777777777777777777777777777777"
    
    # Set up external contract
    redis-cli SET "CODE:$external_addr" "60 FF 00"  # PUSH1 0xFF, STOP
    
    # First call - should compute and cache hash
    redis-cli SET "$contract_addr" "73 77 77 77 77 77 77 77 77 77 77 77 77 77 77 77 77 77 77 77 77 3F 00"
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Second call - should use cached hash
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Both results should be identical
    if [ "$result1" = "$result2" ]; then
        success "EXTCODEHASH Caching Test Passed: Cached hash matches computed hash"
        return 0
    else
        fail "EXTCODEHASH Caching Test Failed" "$result1" "$result2"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=7
    local passed_tests=0

    test_extcodesize && ((passed_tests++))
    test_extcodesize_empty && ((passed_tests++))
    test_extcodecopy && ((passed_tests++))
    test_extcodecopy_bounds && ((passed_tests++))
    test_extcodehash && ((passed_tests++))
    test_extcodehash_empty && ((passed_tests++))
    test_extcodehash_caching && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All External Code Operation Tests Passed!"
        exit 0
    else
        fail "Some External Code Operation Tests Failed"
        exit 1
    fi
}

# Run the main function
main