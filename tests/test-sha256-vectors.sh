#!/bin/bash

# Test SHA-256 precompile with known test vectors

source ./lib.sh

echo "Testing SHA-256 Precompile with Test Vectors..."

# Helper function to convert hex string to bytecode that stores it in memory
hex_to_memory_bytecode() {
    local hex_data="$1"
    local bytecode=""
    local offset=0
    
    # Remove 0x prefix if present
    hex_data="${hex_data#0x}"
    
    # Store each byte in memory using MSTORE8
    while [ ${#hex_data} -gt 0 ]; do
        local byte="${hex_data:0:2}"
        hex_data="${hex_data:2}"
        
        # PUSH1 byte, PUSH1 offset, MSTORE8
        bytecode="$bytecode 60 $byte 60 $(printf '%02x' $offset) 53"
        offset=$((offset + 1))
    done
    
    echo "$bytecode"
}

# Test 1: Empty string
# Expected: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
test_sha256_empty() {
    local contract_addr="0x0000000000000000000000000000000000000200"
    
    # Call SHA256 with empty input, load first word of result
    # PUSH1 0x20 (retLength), PUSH1 0x00 (retOffset), PUSH1 0x00 (argsLength),
    # PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH1 0x02 (address), PUSH2 0xFFFF (gas), CALL
    # PUSH1 0x00 (load first word), MLOAD, STOP
    redis-cli SET "$contract_addr" "60 20 60 00 60 00 60 00 60 00 60 02 61 FF FF F1 60 00 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Check if result starts with e3b0c442 (first 4 bytes of SHA-256 of empty string)
    if [[ "$result" == *"E3B0C442"* ]] || [[ "$result" == *"e3b0c442"* ]]; then
        success "SHA-256 empty string test passed (matches expected hash prefix)"
        return 0
    else
        fail "SHA-256 empty string test failed" "starts with e3b0c442" "$result"
        return 1
    fi
}

# Test 2: Single byte "a" (0x61)
# Expected: ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb
test_sha256_single_byte() {
    local contract_addr="0x0000000000000000000000000000000000000201"
    
    # Store 'a' (0x61) in memory at offset 0
    # PUSH1 0x61, PUSH1 0x00, MSTORE8
    # Then call SHA256
    # PUSH1 0x20 (retLength), PUSH1 0x20 (retOffset), PUSH1 0x01 (argsLength - 1 byte),
    # PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH1 0x02 (address), PUSH2 0xFFFF (gas), CALL
    # PUSH1 0x20 (load result), MLOAD, STOP
    redis-cli SET "$contract_addr" "60 61 60 00 53 60 20 60 20 60 01 60 00 60 00 60 02 61 FF FF F1 60 20 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Check if result starts with ca978112 (first 4 bytes of SHA-256 of "a")
    if [[ "$result" == *"CA978112"* ]] || [[ "$result" == *"ca978112"* ]]; then
        success "SHA-256 single byte 'a' test passed (matches expected hash prefix)"
        return 0
    else
        fail "SHA-256 single byte 'a' test failed" "starts with ca978112" "$result"
        return 1
    fi
}

# Test 3: String "abc"
# Expected: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
test_sha256_abc() {
    local contract_addr="0x0000000000000000000000000000000000000202"
    
    # Store 'abc' (0x61 0x62 0x63) in memory
    # PUSH1 0x61, PUSH1 0x00, MSTORE8
    # PUSH1 0x62, PUSH1 0x01, MSTORE8
    # PUSH1 0x63, PUSH1 0x02, MSTORE8
    # Then call SHA256
    redis-cli SET "$contract_addr" "60 61 60 00 53 60 62 60 01 53 60 63 60 02 53 60 20 60 20 60 03 60 00 60 00 60 02 61 FF FF F1 60 20 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Check if result starts with ba7816bf (first 4 bytes of SHA-256 of "abc")
    if [[ "$result" == *"BA7816BF"* ]] || [[ "$result" == *"ba7816bf"* ]]; then
        success "SHA-256 'abc' test passed (matches expected hash prefix)"
        return 0
    else
        fail "SHA-256 'abc' test failed" "starts with ba7816bf" "$result"
        return 1
    fi
}

# Setup and run tests
setup_redis

echo ""
test_sha256_empty
test_sha256_single_byte
test_sha256_abc

echo ""
echo "SHA-256 test vector validation completed!"
