#!/bin/bash

# Source library functions
source ./lib.sh

# Test KECCAK256 with empty data
test_keccak256_empty() {
    local contract_addr="0x0000000000000000000000000000000000000020"
    # Bytecode: PUSH1 0 (length), PUSH1 0 (offset), KECCAK256, STOP
    redis-cli SET "$contract_addr" "60 00 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    # Expected: keccak256("") = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470
    local expected="0xC5D2460186F7233C927E7DB2DCC703C0E500B653CA82273B7BFAD8045D85A470"
    
    if [ "$result" = "$expected" ]; then
        success "KECCAK256 Empty Data Test Passed: Correct hash for empty input"
        return 0
    else
        fail "KECCAK256 Empty Data Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test KECCAK256 with single byte 0x00
test_keccak256_single_byte() {
    local contract_addr="0x0000000000000000000000000000000000000021"
    # Bytecode: PUSH1 0x00, PUSH1 0, MSTORE8, PUSH1 1 (length), PUSH1 0 (offset), KECCAK256, STOP
    redis-cli SET "$contract_addr" "60 00 60 00 53 60 01 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    # Expected: keccak256(0x00) = 0xbc36789e7a1e281436464229828f817d6612f7b477d66591ff96a9e064bcc98a
    local expected="0xBC36789E7A1E281436464229828F817D6612F7B477D66591FF96A9E064BCC98A"
    
    if [ "$result" = "$expected" ]; then
        success "KECCAK256 Single Byte Test Passed: Correct hash for 0x00"
        return 0
    else
        fail "KECCAK256 Single Byte Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test KECCAK256 with "abc" string
test_keccak256_abc() {
    local contract_addr="0x0000000000000000000000000000000000000022"
    # Store "abc" (0x616263) in memory and hash it
    # Bytecode: PUSH1 0x61, PUSH1 0, MSTORE8, PUSH1 0x62, PUSH1 1, MSTORE8, PUSH1 0x63, PUSH1 2, MSTORE8, PUSH1 3, PUSH1 0, KECCAK256, STOP
    redis-cli SET "$contract_addr" "60 61 60 00 53 60 62 60 01 53 60 63 60 02 53 60 03 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    # Expected: keccak256("abc") = 0x4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45
    local expected="0x4E03657AEA45A94FC7D47BA826C8D667C0D1E6E33A64A036EC44F58FA12D6C45"
    
    if [ "$result" = "$expected" ]; then
        success "KECCAK256 ABC Test Passed: Correct hash for 'abc'"
        return 0
    else
        fail "KECCAK256 ABC Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test KECCAK256 with single byte 0xFF
test_keccak256_ff_byte() {
    local contract_addr="0x0000000000000000000000000000000000000023"
    # Bytecode: PUSH1 0xFF, PUSH1 0, MSTORE8, PUSH1 1, PUSH1 0, KECCAK256, STOP
    redis-cli SET "$contract_addr" "60 FF 60 00 53 60 01 60 00 20 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    # Expected: keccak256(0xFF) = 0xa8100ae6aa1940d0b663bb31cd466142ebbdbd5187131b92d93818987832eb89
    local expected="0xA8100AE6AA1940D0B663BB31CD466142EBBDBD5187131B92D93818987832EB89"
    
    if [ "$result" = "$expected" ]; then
        success "KECCAK256 FF Byte Test Passed: Correct hash for 0xFF"
        return 0
    else
        fail "KECCAK256 FF Byte Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test KECCAK256 consistency (same input should produce same hash)
test_keccak256_consistency() {
    local contract_addr1="0x0000000000000000000000000000000000000024"
    local contract_addr2="0x0000000000000000000000000000000000000025"
    
    # Same bytecode for both contracts: hash empty data
    local bytecode="60 00 60 00 20 00"
    redis-cli SET "$contract_addr1" "$bytecode"
    redis-cli SET "$contract_addr2" "$bytecode"
    
    local result1=$(redis-cli FCALL eth_call 1 "$contract_addr1")
    local result2=$(redis-cli FCALL eth_call 1 "$contract_addr2")
    
    if [ "$result1" = "$result2" ]; then
        success "KECCAK256 Consistency Test Passed: Same input produces same hash"
        return 0
    else
        fail "KECCAK256 Consistency Test Failed" "$result1" "$result2"
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
    test_keccak256_abc && ((passed_tests++))
    test_keccak256_ff_byte && ((passed_tests++))
    test_keccak256_consistency && ((passed_tests++))

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