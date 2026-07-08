#!/bin/bash

# Source library functions
source ./lib.sh

# Test TSTORE opcode (0x5D)
test_tstore() {
    local contract_addr="0x0000000000000000000000000000000000000100"
    
    # Bytecode: PUSH1 0x42, PUSH1 0x05, TSTORE, PUSH1 0x99, STOP
    # This stores 0x42 at transient storage position 5, then returns 0x99
    redis-cli SET "$contract_addr" "60 42 60 05 5D 60 99 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x99 (just to verify the operation completed)
    if [ "$result" = "0x99" ]; then
        success "TSTORE Test Passed: TSTORE operation completed"
        return 0
    else
        fail "TSTORE Test Failed" "0x99" "$result"
        return 1
    fi
}

# Test TLOAD opcode (0x5C)
test_tload() {
    local contract_addr="0x0000000000000000000000000000000000000101"
    
    # Bytecode: PUSH1 0x42, PUSH1 0x05, TSTORE, PUSH1 0x05, TLOAD, STOP
    # This stores 0x42 at position 5, then loads from position 5
    redis-cli SET "$contract_addr" "60 42 60 05 5D 60 05 5C 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x42 (the value we stored)
    if [ "$result" = "0x42" ]; then
        success "TLOAD Test Passed: Successfully loaded stored value"
        return 0
    else
        fail "TLOAD Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test TLOAD from empty position
test_tload_empty() {
    local contract_addr="0x0000000000000000000000000000000000000102"
    
    # Bytecode: PUSH1 0x10, TLOAD, STOP
    # This loads from position 16 (which should be empty/zero)
    redis-cli SET "$contract_addr" "60 10 5C 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x00 (default value for empty storage)
    if [ "$result" = "0x00" ]; then
        success "TLOAD Empty Test Passed: Empty position returns 0"
        return 0
    else
        fail "TLOAD Empty Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test multiple TSTORE/TLOAD operations
test_multiple_transient_ops() {
    local contract_addr="0x0000000000000000000000000000000000000103"
    
    # Bytecode: PUSH1 0x11, PUSH1 0x01, TSTORE, PUSH1 0x22, PUSH1 0x02, TSTORE, PUSH1 0x01, TLOAD, PUSH1 0x02, TLOAD, ADD, STOP
    # Store 0x11 at pos 1, store 0x22 at pos 2, load both and add them (0x11 + 0x22 = 0x33)
    redis-cli SET "$contract_addr" "60 11 60 01 5D 60 22 60 02 5D 60 01 5C 60 02 5C 01 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x33 (0x11 + 0x22)
    if [ "$result" = "0x33" ]; then
        success "Multiple Transient Ops Test Passed: Correctly stored and loaded multiple values"
        return 0
    else
        fail "Multiple Transient Ops Test Failed" "0x33" "$result"
        return 1
    fi
}

# Test TSTORE overwrite
test_tstore_overwrite() {
    local contract_addr="0x0000000000000000000000000000000000000104"
    
    # Bytecode: PUSH1 0x42, PUSH1 0x05, TSTORE, PUSH1 0x99, PUSH1 0x05, TSTORE, PUSH1 0x05, TLOAD, STOP
    # Store 0x42 at pos 5, then overwrite with 0x99, then load from pos 5
    redis-cli SET "$contract_addr" "60 42 60 05 5D 60 99 60 05 5D 60 05 5C 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x99 (the overwritten value)
    if [ "$result" = "0x99" ]; then
        success "TSTORE Overwrite Test Passed: Successfully overwrote transient storage value"
        return 0
    else
        fail "TSTORE Overwrite Test Failed" "0x99" "$result"
        return 1
    fi
}

# Test transient storage isolation (different contracts should have separate transient storage)
test_transient_isolation() {
    local contract_addr1="0x0000000000000000000000000000000000000105"
    local contract_addr2="0x0000000000000000000000000000000000000106"
    
    # Contract 1: Store 0x42 at position 1, then return it
    redis-cli SET "$contract_addr1" "60 42 60 01 5D 60 01 5C 00"
    
    # Contract 2: Try to load from position 1 (should be empty)
    redis-cli SET "$contract_addr2" "60 01 5C 00"
    
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr1")
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    # Contract 1 should return 0x42, Contract 2 should return 0x00
    if [ "$result1" = "0x42" ] && [ "$result2" = "0x00" ]; then
        success "Transient Isolation Test Passed: Transient storage is properly isolated between contracts"
        return 0
    else
        fail "Transient Isolation Test Failed" "Contract1: 0x42, Contract2: 0x00" "Contract1: $result1, Contract2: $result2"
        return 1
    fi
}

# Test large values in transient storage
test_transient_large_values() {
    local contract_addr="0x0000000000000000000000000000000000000107"
    
    # Bytecode: PUSH2 0x1234, PUSH1 0x01, TSTORE, PUSH1 0x01, TLOAD, STOP
    # Store 0x1234 at position 1, then load it back
    redis-cli SET "$contract_addr" "61 12 34 60 01 5D 60 01 5C 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Expected: 0x1234
    if [ "$result" = "0x1234" ]; then
        success "Transient Large Values Test Passed: Successfully stored and loaded large value"
        return 0
    else
        fail "Transient Large Values Test Failed" "0x1234" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=7
    local passed_tests=0

    test_tstore && ((passed_tests++))
    test_tload && ((passed_tests++))
    test_tload_empty && ((passed_tests++))
    test_multiple_transient_ops && ((passed_tests++))
    test_tstore_overwrite && ((passed_tests++))
    test_transient_isolation && ((passed_tests++))
    test_transient_large_values && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Transient Storage Tests Passed!"
        exit 0
    else
        fail "Some Transient Storage Tests Failed"
        exit 1
    fi
}

# Run the main function
main