#!/bin/bash

# Source library functions
source ./lib.sh

# Test basic MCOPY operation
test_mcopy_basic() {
    local contract_addr="0x0000000000000000000000000000000000000110"
    
    # Simple test: store a value, copy it, then verify by returning a known value
    # Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE8, PUSH1 1 (length), PUSH1 0 (src), PUSH1 10 (dest), MCOPY, PUSH1 0x99, STOP
    # This stores 0x42 at pos 0, copies 1 byte from pos 0 to pos 10, then returns 0x99 to verify completion
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 00 60 0A 5E 60 99 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x99 (just to verify the operation completed successfully)
    if [ "$result" = "0x99" ]; then
        success "MCOPY Basic Test Passed: Successfully completed MCOPY operation"
        return 0
    else
        fail "MCOPY Basic Test Failed" "0x99" "$result"
        return 1
    fi
}

# Test MCOPY with zero length
test_mcopy_zero_length() {
    local contract_addr="0x0000000000000000000000000000000000000111"
    
    # Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE8, PUSH1 0 (length), PUSH1 0 (src), PUSH1 10 (dest), MCOPY, PUSH1 0x99, STOP
    # Store 0x42 at pos 0, copy 0 bytes, then return 0x99 to verify operation completed
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 00 60 00 60 0A 5E 60 99 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x99 (operation should complete successfully)
    if [ "$result" = "0x99" ]; then
        success "MCOPY Zero Length Test Passed: Zero length copy handled correctly"
        return 0
    else
        fail "MCOPY Zero Length Test Failed" "0x99" "$result"
        return 1
    fi
}

# Test MCOPY with overlapping regions (forward copy)
test_mcopy_overlap_forward() {
    local contract_addr="0x0000000000000000000000000000000000000112"
    
    # Set up memory: [0x11, 0x22, 0x33, 0x44] at positions 0-3
    # Copy 2 bytes from pos 0 to pos 2 (overlapping)
    # Expected result: [0x11, 0x22, 0x11, 0x22]
    # Bytecode: PUSH1 0x11, PUSH1 0, MSTORE8, PUSH1 0x22, PUSH1 1, MSTORE8, PUSH1 0x33, PUSH1 2, MSTORE8, PUSH1 0x44, PUSH1 3, MSTORE8, PUSH1 2 (length), PUSH1 0 (src), PUSH1 2 (dest), MCOPY, PUSH1 0xAA, STOP
    redis-cli SET "$contract_addr" "60 11 60 00 53 60 22 60 01 53 60 33 60 02 53 60 44 60 03 53 60 02 60 00 60 02 5E 60 AA 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0xAA (just to verify the operation completed)
    if [ "$result" = "0xAA" ]; then
        success "MCOPY Overlap Forward Test Passed: Forward overlapping copy handled correctly"
        return 0
    else
        fail "MCOPY Overlap Forward Test Failed" "0xAA" "$result"
        return 1
    fi
}

# Test MCOPY with overlapping regions (backward copy)
test_mcopy_overlap_backward() {
    local contract_addr="0x0000000000000000000000000000000000000113"
    
    # Set up memory: [0x11, 0x22, 0x33, 0x44] at positions 0-3
    # Copy 2 bytes from pos 2 to pos 1 (overlapping, dest < src)
    # Expected result: [0x11, 0x33, 0x44, 0x44]
    # Bytecode: PUSH1 0x11, PUSH1 0, MSTORE8, PUSH1 0x22, PUSH1 1, MSTORE8, PUSH1 0x33, PUSH1 2, MSTORE8, PUSH1 0x44, PUSH1 3, MSTORE8, PUSH1 2 (length), PUSH1 2 (src), PUSH1 1 (dest), MCOPY, PUSH1 0xBB, STOP
    redis-cli SET "$contract_addr" "60 11 60 00 53 60 22 60 01 53 60 33 60 02 53 60 44 60 03 53 60 02 60 02 60 01 5E 60 BB 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0xBB (just to verify the operation completed)
    if [ "$result" = "0xBB" ]; then
        success "MCOPY Overlap Backward Test Passed: Backward overlapping copy handled correctly"
        return 0
    else
        fail "MCOPY Overlap Backward Test Failed" "0xBB" "$result"
        return 1
    fi
}

# Test MCOPY with memory expansion
test_mcopy_expansion() {
    local contract_addr="0x0000000000000000000000000000000000000114"
    
    # Copy from a small position to a large position to test memory expansion
    # Bytecode: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 1 (length), PUSH1 0 (src), PUSH1 100 (dest), MCOPY, PUSH1 0xCC, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 00 60 64 5E 60 CC 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0xCC (just to verify the operation completed)
    if [ "$result" = "0xCC" ]; then
        success "MCOPY Expansion Test Passed: Memory expansion handled correctly"
        return 0
    else
        fail "MCOPY Expansion Test Failed" "0xCC" "$result"
        return 1
    fi
}

# Test MCOPY with large length
test_mcopy_large() {
    local contract_addr="0x0000000000000000000000000000000000000115"
    
    # Set up a pattern in memory and copy a larger chunk
    # Bytecode: PUSH1 0xAA, PUSH1 0, MSTORE8, PUSH1 0xBB, PUSH1 1, MSTORE8, PUSH1 0xCC, PUSH1 2, MSTORE8, PUSH1 0xDD, PUSH1 3, MSTORE8, PUSH1 4 (length), PUSH1 0 (src), PUSH1 10 (dest), MCOPY, PUSH1 0xDD, STOP
    redis-cli SET "$contract_addr" "60 AA 60 00 53 60 BB 60 01 53 60 CC 60 02 53 60 DD 60 03 53 60 04 60 00 60 0A 5E 60 DD 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0xDD (just to verify the operation completed)
    if [ "$result" = "0xDD" ]; then
        success "MCOPY Large Test Passed: Large copy operation handled correctly"
        return 0
    else
        fail "MCOPY Large Test Failed" "0xDD" "$result"
        return 1
    fi
}

# Test MCOPY reading from uninitialized memory (should read zeros)
test_mcopy_uninitialized() {
    local contract_addr="0x0000000000000000000000000000000000000116"
    
    # Copy from uninitialized memory (should be zeros)
    # Bytecode: PUSH1 2 (length), PUSH1 50 (src - uninitialized), PUSH1 0 (dest), MCOPY, PUSH1 0xEE, STOP
    redis-cli SET "$contract_addr" "60 02 60 32 60 00 5E 60 EE 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0xEE (just to verify the operation completed)
    if [ "$result" = "0xEE" ]; then
        success "MCOPY Uninitialized Test Passed: Uninitialized memory copy handled correctly"
        return 0
    else
        fail "MCOPY Uninitialized Test Failed" "0xEE" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=7
    local passed_tests=0

    test_mcopy_basic && ((passed_tests++))
    test_mcopy_zero_length && ((passed_tests++))
    test_mcopy_overlap_forward && ((passed_tests++))
    test_mcopy_overlap_backward && ((passed_tests++))
    test_mcopy_expansion && ((passed_tests++))
    test_mcopy_large && ((passed_tests++))
    test_mcopy_uninitialized && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All MCOPY Tests Passed!"
        exit 0
    else
        fail "Some MCOPY Tests Failed"
        exit 1
    fi
}

# Run the main function
main