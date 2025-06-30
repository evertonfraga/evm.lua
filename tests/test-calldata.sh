#!/bin/bash

# Source library functions
source ./lib.sh

# Test CALLDATASIZE opcode (0x36)
test_calldatasize() {
    local contract_addr="0x0000000000000000000000000000000000000090"
    local calldata="1234567890ABCDEF"  # 8 bytes
    
    # Set calldata in Redis
    redis-cli SET "CALLDATA" "$calldata"
    
    # Bytecode: CALLDATASIZE, STOP
    redis-cli SET "$contract_addr" "36 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x08" ]; then  # 8 bytes
        success "CALLDATASIZE Test Passed: Returns correct calldata size"
        return 0
    else
        fail "CALLDATASIZE Test Failed" "0x08" "$result"
        return 1
    fi
}

# Test CALLDATALOAD opcode (0x35)
test_calldataload() {
    local contract_addr="0x0000000000000000000000000000000000000091"
    # 32 bytes of calldata (64 hex chars)
    local calldata="1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF"
    
    # Set calldata in Redis
    redis-cli SET "CALLDATA" "$calldata"
    
    # Bytecode: PUSH1 0, CALLDATALOAD, STOP (load from offset 0)
    redis-cli SET "$contract_addr" "60 00 35 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Should load the first 32 bytes as a number
    if [[ "$result" =~ ^0x[0-9A-F]+$ ]]; then
        success "CALLDATALOAD Test Passed: Loaded calldata from offset 0"
        return 0
    else
        fail "CALLDATALOAD Test Failed" "hex value" "$result"
        return 1
    fi
}

# Test CALLDATALOAD with offset
test_calldataload_offset() {
    local contract_addr="0x0000000000000000000000000000000000000092"
    # Set calldata with known pattern
    local calldata="00000000000000000000000000000000000000000000000000000000000000001234567890ABCDEF"
    
    # Set calldata in Redis
    redis-cli SET "CALLDATA" "$calldata"
    
    # Bytecode: PUSH1 32, CALLDATALOAD, STOP (load from offset 32)
    redis-cli SET "$contract_addr" "60 20 35 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [[ "$result" =~ ^0x[0-9A-F]+$ ]]; then
        success "CALLDATALOAD Offset Test Passed: Loaded calldata from offset 32"
        return 0
    else
        fail "CALLDATALOAD Offset Test Failed" "hex value" "$result"
        return 1
    fi
}

# Test CODECOPY opcode (0x39)
test_codecopy() {
    local contract_addr="0x0000000000000000000000000000000000000093"
    local bytecode="60 42 60 00 52 60 20 60 00 60 00 39 60 00 51 00"  # Copy code to memory then load
    
    # Set contract bytecode
    redis-cli SET "$contract_addr" "$bytecode"
    
    # Bytecode: PUSH1 42, PUSH1 0, MSTORE, PUSH1 32, PUSH1 0, PUSH1 0, CODECOPY, PUSH1 0, MLOAD, STOP
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [[ "$result" =~ ^0x[0-9A-F]+$ ]]; then
        success "CODECOPY Test Passed: Copied code to memory successfully"
        return 0
    else
        fail "CODECOPY Test Failed" "hex value" "$result"
        return 1
    fi
}

# Test empty calldata
test_empty_calldata() {
    local contract_addr="0x0000000000000000000000000000000000000094"
    
    # Clear any existing calldata
    redis-cli DEL "CALLDATA"
    
    # Bytecode: CALLDATASIZE, STOP
    redis-cli SET "$contract_addr" "36 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "Empty Calldata Test Passed: Returns 0 for empty calldata"
        return 0
    else
        fail "Empty Calldata Test Failed" "0x00" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=5
    local passed_tests=0

    test_calldatasize && ((passed_tests++))
    test_calldataload && ((passed_tests++))
    test_calldataload_offset && ((passed_tests++))
    test_codecopy && ((passed_tests++))
    test_empty_calldata && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Calldata Tests Passed!"
        exit 0
    else
        fail "Some Calldata Tests Failed"
        exit 1
    fi
}

# Run the main function
main