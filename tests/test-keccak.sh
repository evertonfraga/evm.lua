#!/bin/bash

# Source library functions
source ./lib.sh

# Test KECCAK256 with empty data
test_keccak256_empty() {
    local contract_addr="0x0000000000000000000000000000000000000020"
    # Bytecode: PUSH1 0 (length), PUSH1 0 (offset), KECCAK256, STOP
    redis-cli SET "$contract_addr" "60 00 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Check if we get a valid hash (starts with 0x and has 64 hex chars)
    if [[ "$result" =~ ^0x[0-9A-F]{64}$ ]]; then
        success "KECCAK256 Empty Data Test Passed: Got hash $result"
        return 0
    else
        fail "KECCAK256 Empty Data Test Failed" "0x[64 hex chars]" "$result"
        return 1
    fi
}

# Test KECCAK256 with single byte
test_keccak256_single_byte() {
    local contract_addr="0x0000000000000000000000000000000000000021"
    # Bytecode: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 1 (length), PUSH1 0 (offset), KECCAK256, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [[ "$result" =~ ^0x[0-9A-F]{64}$ ]]; then
        success "KECCAK256 Single Byte Test Passed: Got hash $result"
        return 0
    else
        fail "KECCAK256 Single Byte Test Failed" "0x[64 hex chars]" "$result"
        return 1
    fi
}

# Test KECCAK256 with 32 bytes of data
test_keccak256_32_bytes() {
    local contract_addr="0x0000000000000000000000000000000000000022"
    # Bytecode: PUSH32 (Hello World + padding), PUSH1 0, MSTORE, PUSH1 32, PUSH1 0, KECCAK256, STOP
    redis-cli SET "$contract_addr" "7f 48 65 6c 6c 6f 20 57 6f 72 6c 64 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 60 00 52 60 20 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [[ "$result" =~ ^0x[0-9A-F]{64}$ ]]; then
        success "KECCAK256 32 Bytes Test Passed: Got hash $result"
        return 0
    else
        fail "KECCAK256 32 Bytes Test Failed" "0x[64 hex chars]" "$result"
        return 1
    fi
}

# Test KECCAK256 consistency (same input should produce same hash)
test_keccak256_consistency() {
    local contract_addr1="0x0000000000000000000000000000000000000023"
    local contract_addr2="0x0000000000000000000000000000000000000024"
    
    # Same bytecode for both contracts: PUSH1 0x42, PUSH1 0, MSTORE8, PUSH1 1, PUSH1 0, KECCAK256, STOP
    local bytecode="60 42 60 00 53 60 01 60 00 20 00"
    redis-cli SET "$contract_addr1" "$bytecode"
    redis-cli SET "$contract_addr2" "$bytecode"
    
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr1")
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result1" = "$result2" ]; then
        success "KECCAK256 Consistency Test Passed: Same input produces same hash ($result1)"
        return 0
    else
        fail "KECCAK256 Consistency Test Failed" "$result1" "$result2"
        return 1
    fi
}

# Test KECCAK256 with different inputs produce different hashes
test_keccak256_different_inputs() {
    local contract_addr1="0x0000000000000000000000000000000000000025"
    local contract_addr2="0x0000000000000000000000000000000000000026"
    
    # First contract: hash byte 0x42
    redis-cli SET "$contract_addr1" "60 42 60 00 53 60 01 60 00 20 00"
    
    # Second contract: hash byte 0x43
    redis-cli SET "$contract_addr2" "60 43 60 00 53 60 01 60 00 20 00"
    
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr1")
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result1" != "$result2" ]; then
        success "KECCAK256 Different Inputs Test Passed: Different inputs produce different hashes"
        return 0
    else
        fail "KECCAK256 Different Inputs Test Failed" "Different hashes" "Same hash: $result1"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=5
    local passed_tests=0

    test_keccak256_empty && ((passed_tests++))
    test_keccak256_single_byte && ((passed_tests++))
    test_keccak256_32_bytes && ((passed_tests++))
    test_keccak256_consistency && ((passed_tests++))
    test_keccak256_different_inputs && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All KECCAK256 Tests Passed!"
        exit 0
    else
        fail "Some KECCAK256 Tests Failed"
        exit 1
    fi
}

# Run the main function
main