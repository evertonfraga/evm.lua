#!/bin/bash

# Source library functions
source ./lib.sh

redis-cli FLUSHDB

# Test SLOAD opcode (0x54)
test_sload() {
    local contract_addr="0x0000000000000000000000000000000000000040"
    
    # First, set up some storage data in Redis
    redis-cli SET "${contract_addr}:00" "0x2A"  # Store 42 at storage position 0
    redis-cli SET "${contract_addr}:01" "0xFF"  # Store 255 at storage position 1
    
    # Test loading from storage position 0
    # Bytecode: PUSH1 0, SLOAD, STOP (load from storage position 0)
    redis-cli SET "$contract_addr" "60 00 54 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "SLOAD Test 1 Passed: Loaded value 42 (0x2A) from storage position 0"
    else
        fail "SLOAD Test 1 Failed" "0x2A" "$result"
        return 1
    fi
}

test_sload_slot_1(){
    # Test loading from storage position 1
    local contract_addr="0x0000000000000000000000000000000000000041"
    redis-cli SET "${contract_addr}:00" "0x2A"  # Store 42 at storage position 0
    redis-cli SET "${contract_addr}:01" "0xFF"  # Store 255 at storage position 1

    # Bytecode: PUSH1 1, SLOAD, STOP (load from storage position 1)
    redis-cli SET "$contract_addr" "60 01 54 00"
    
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result2" = "0xFF" ]; then
        success "SLOAD Test 2 Passed: Loaded value 255 (0xFF) from storage position 1"
        return 0
    else
        fail "SLOAD Test 2 Failed" "0xFF" "$result2"
        return 1
    fi

}

# Test SLOAD with non-existent storage key
test_sload_empty() {
    local contract_addr="0x0000000000000000000000000000000000000042"
    
    # Make sure storage position 99 doesn't exist
    redis-cli DEL "${contract_addr}:99"
    
    # Bytecode: PUSH1 99, SLOAD, STOP (load from non-existent storage position)
    redis-cli SET "$contract_addr" "60 63 54 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "SLOAD Empty Test Passed: Non-existent storage returns 0 (0x00)"
        return 0
    else
        fail "SLOAD Empty Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test SLOAD with complex storage operations
test_sload_complex() {
    local contract_addr="0x0000000000000000000000000000000000000043"
    
    # Set up storage with hex values
    redis-cli SET "${contract_addr}:0A" "0x1234"
    redis-cli SET "${contract_addr}:14" "0xABCD"
    
    # Test 1: Load from position 10
    # Bytecode: PUSH1 10, SLOAD, STOP
    redis-cli SET "$contract_addr" "60 0A 54 00"
    
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result1" = "0x1234" ]; then
        success "SLOAD Complex Test 1 Passed: Loaded 0x1234 from position 10"
    else
        fail "SLOAD Complex Test 1 Failed" "0x1234" "$result1"
        return 1
    fi
}

test_sload_complex_2() {
    local contract_addr="0x0000000000000000000000000000000000000044"
    
    # Set up storage with hex values
    redis-cli SET "${contract_addr}:0A" "0x1234"
    redis-cli SET "${contract_addr}:14" "0xABCD"
    
    # Test 1: Load from position 10
    # Bytecode: PUSH1 10, SLOAD, STOP
    redis-cli SET "$contract_addr" "60 14 54 00"
    
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result1" = "0xABCD" ]; then
        success "SLOAD Complex Test 2 Passed: Loaded 0xABCD from position 20"
    else
        fail "SLOAD Complex Test 2 Failed" "0xABCD" "$result1"
        return 1
    fi
}


# Test SLOAD with computed storage position
test_sload_computed_position() {
    local contract_addr="0x0000000000000000000000000000000000000045"
    
    # Set up storage at position 15 (0x0F)
    redis-cli SET "${contract_addr}:0F" "0x42"
    
    # Bytecode: PUSH1 10, PUSH1 5, ADD, SLOAD, STOP (compute 10+5=15, then load from position 15)
    redis-cli SET "$contract_addr" "60 0A 60 05 01 54 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "SLOAD Computed Position Test Passed: Loaded 0x42 from computed position 15"
        return 0
    else
        fail "SLOAD Computed Position Test Failed" "0x42" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=6
    local passed_tests=0

    test_sload && ((passed_tests++))
    test_sload_slot_1 && ((passed_tests++))
    test_sload_empty && ((passed_tests++))
    test_sload_complex && ((passed_tests++))
    test_sload_complex_2 && ((passed_tests++))
    test_sload_computed_position && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Storage Opcode Tests Passed!"
        exit 0
    else
        fail "Some Storage Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main
