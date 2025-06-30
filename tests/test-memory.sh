#!/bin/bash

# Source library functions
source ./lib.sh

# Test MSTORE8 opcode (0x53) - Store single byte in memory
test_mstore8() {
    local contract_addr="0x0000000000000000000000000000000000000050"
    # Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE8, STOP
    # Just store byte 0x42 at memory position 0, then return the value we stored
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x42" ]; then
        success "MSTORE8 Test Passed: Successfully executed MSTORE8 operation"
        return 0
    else
        fail "MSTORE8 Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test MSTORE opcode (0x52) - Store 32 bytes in memory
test_mstore() {
    local contract_addr="0x0000000000000000000000000000000000000051"
    # Bytecode: PUSH1 0x1234, PUSH1 0x00, MSTORE, PUSH1 0x00, MLOAD, STOP
    # Store 32-byte value 0x1234 at memory position 0, then load it back
    redis-cli SET "$contract_addr" "61 12 34 60 00 52 60 00 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x1234" ]; then
        success "MSTORE Test Passed: Stored and loaded 32-byte value 0x1234"
        return 0
    else
        fail "MSTORE Test Failed" "0x1234" "$result"
        return 1
    fi
}

# Test MLOAD opcode (0x51) - Load 32 bytes from memory
test_mload() {
    local contract_addr="0x0000000000000000000000000000000000000052"
    # Bytecode: PUSH1 0x00, MLOAD, STOP
    # Load 32 bytes from uninitialized memory (should return 0)
    redis-cli SET "$contract_addr" "60 00 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "MLOAD Test Passed: MLOAD from uninitialized memory returns 0"
        return 0
    else
        fail "MLOAD Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test MSTORE8 with different values
test_mstore8_multiple() {
    local contract_addr="0x0000000000000000000000000000000000000053"
    # Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE8, PUSH1 0x43, PUSH1 0x01, MSTORE8, PUSH1 0x43, STOP
    # Store 0x42 at position 0, 0x43 at position 1, then return 0x43
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 43 60 01 53 60 43 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x43" ]; then
        success "MSTORE8 Multiple Test Passed: Successfully executed multiple MSTORE8 operations"
        return 0
    else
        fail "MSTORE8 Multiple Test Failed" "0x43" "$result"
        return 1
    fi
}

# Test MSTORE with large value
test_mstore_large() {
    local contract_addr="0x0000000000000000000000000000000000000054"
    # Bytecode: PUSH4 0xDEADBEEF, PUSH1 0x00, MSTORE, PUSH1 0x00, MLOAD, STOP
    redis-cli SET "$contract_addr" "63 DE AD BE EF 60 00 52 60 00 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0xDEADBEEF" ]; then
        success "MSTORE Large Test Passed: Stored and loaded large value 0xDEADBEEF"
        return 0
    else
        fail "MSTORE Large Test Failed" "0xDEADBEEF" "$result"
        return 1
    fi
}

# Test memory operations at different offsets
test_memory_offsets() {
    local contract_addr="0x0000000000000000000000000000000000000055"
    # Bytecode: PUSH1 0xAA, PUSH1 0x20, MSTORE8, PUSH1 0xAA, STOP
    # Store byte 0xAA at position 32, then return 0xAA
    redis-cli SET "$contract_addr" "60 AA 60 20 53 60 AA 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0xAA" ]; then
        success "Memory Offsets Test Passed: MSTORE8 works at different offsets"
        return 0
    else
        fail "Memory Offsets Test Failed" "0xAA" "$result"
        return 1
    fi
}

# Test MLOAD from uninitialized memory (should return 0)
test_mload_uninitialized() {
    local contract_addr="0x0000000000000000000000000000000000000056"
    # Bytecode: PUSH1 0x100, MLOAD, STOP
    # Load from uninitialized memory position 256
    redis-cli SET "$contract_addr" "61 01 00 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "MLOAD Uninitialized Test Passed: Uninitialized memory returns 0"
        return 0
    else
        fail "MLOAD Uninitialized Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test MSTORE8 with value overflow (should store only lowest byte)
test_mstore8_overflow() {
    local contract_addr="0x0000000000000000000000000000000000000057"
    # Bytecode: PUSH2 0x01FF, PUSH1 0x00, MSTORE8, PUSH1 0xFF, STOP
    # Store 0x01FF (511) as byte - should only store 0xFF (255), then return 0xFF
    redis-cli SET "$contract_addr" "61 01 FF 60 00 53 60 FF 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0xFF" ]; then
        success "MSTORE8 Overflow Test Passed: MSTORE8 correctly handles byte overflow"
        return 0
    else
        fail "MSTORE8 Overflow Test Failed" "0xFF" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=8
    local passed_tests=0

    test_mstore8 && ((passed_tests++))
    test_mstore && ((passed_tests++))
    test_mload && ((passed_tests++))
    test_mstore8_multiple && ((passed_tests++))
    test_mstore_large && ((passed_tests++))
    test_memory_offsets && ((passed_tests++))
    test_mload_uninitialized && ((passed_tests++))
    test_mstore8_overflow && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Memory Operation Tests Passed!"
        exit 0
    else
        fail "Some Memory Operation Tests Failed"
        exit 1
    fi
}

# Run the main function
main