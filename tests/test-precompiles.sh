#!/bin/bash

# Test precompiled contracts

source ./lib.sh

echo "Testing Precompiled Contracts..."

# Test 0x04: Identity (data copy) - simplest precompile
test_identity() {
    local contract_addr="0x0000000000000000000000000000000000000100"
    # Bytecode: Store 0x42 in memory, CALL identity precompile, check result
    # PUSH1 0x42, PUSH1 0x00, MSTORE8
    # CALL(gas, address, value, argsOffset, argsLength, retOffset, retLength)
    # PUSH1 0x01 (retLength), PUSH1 0x20 (retOffset), PUSH1 0x01 (argsLength), 
    # PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH1 0x04 (address), PUSH2 0xFFFF (gas), CALL
    # PUSH1 0x20, MLOAD, STOP
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 20 60 01 60 00 60 00 60 04 61 FF FF F1 60 20 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Result should contain 0x42 (the identity function returns what was sent, padded to 32 bytes)
    if [[ "$result" == *"42"* ]]; then
        success "Identity precompile (0x04) test passed"
        return 0
    else
        fail "Identity precompile (0x04) test failed" "contains 0x42" "$result"
        return 1
    fi
}

# Test 0x02: SHA256 - test with empty input
test_sha256_empty() {
    local contract_addr="0x0000000000000000000000000000000000000101"
    # Bytecode: CALL SHA256 with empty input
    # CALL(gas, address, value, argsOffset, argsLength, retOffset, retLength)
    # PUSH1 0x20 (retLength), PUSH1 0x00 (retOffset), PUSH1 0x00 (argsLength - empty),
    # PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH1 0x02 (address), PUSH2 0xFFFF (gas), CALL, STOP
    redis-cli SET "$contract_addr" "60 20 60 00 60 00 60 00 60 00 60 02 61 FF FF F1 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Result should be 1 (success) on the stack
    if [ "$result" = "0x01" ]; then
        success "SHA256 precompile (0x02) empty input test passed"
        return 0
    else
        fail "SHA256 precompile (0x02) empty input test failed" "0x01" "$result"
        return 1
    fi
}

# Test 0x01: ECRecover - basic call test
test_ecrecover_call() {
    local contract_addr="0x0000000000000000000000000000000000000102"
    # Bytecode: CALL ECRecover (just test it doesn't crash)
    # PUSH1 0x20 (retLength), PUSH1 0x00 (retOffset), PUSH1 0x80 (argsLength - 128 bytes),
    # PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH1 0x01 (address), PUSH2 0xFFFF (gas), CALL, STOP
    redis-cli SET "$contract_addr" "60 20 60 00 60 80 60 00 60 00 60 01 61 FF FF F1 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Result should be 1 (success) - we're just testing it executes
    if [ "$result" = "0x01" ]; then
        success "ECRecover precompile (0x01) call test passed"
        return 0
    else
        fail "ECRecover precompile (0x01) call test failed" "0x01" "$result"
        return 1
    fi
}

# Test 0x03: RIPEMD-160 - basic call test
test_ripemd160_call() {
    local contract_addr="0x0000000000000000000000000000000000000103"
    # Bytecode: CALL RIPEMD-160
    redis-cli SET "$contract_addr" "60 20 60 00 60 00 60 00 60 00 60 03 61 FF FF F1 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "RIPEMD-160 precompile (0x03) call test passed"
        return 0
    else
        fail "RIPEMD-160 precompile (0x03) call test failed" "0x01" "$result"
        return 1
    fi
}

# Setup and run tests
setup_redis

echo ""
test_identity
test_sha256_empty
test_ecrecover_call
test_ripemd160_call

echo ""
echo "Precompile tests completed!"
