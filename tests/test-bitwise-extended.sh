#!/bin/bash

# Test extended bitwise opcodes (XOR, BYTE, SHL, SAR)

source ./lib.sh

# Test XOR opcode (0x18) - Bitwise exclusive OR
test_xor() {
    local contract_addr="0x0000000000000000000000000000000000000018"
    # Bytecode: PUSH1 0x0F, PUSH1 0x33, XOR, STOP
    # 0x33 XOR 0x0F = 0x3C
    redis-cli SET "$contract_addr" "60 0F 60 33 18 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x3C" ]; then
        success "XOR Test Passed: 0x33 XOR 0x0F = 0x3C ($result)"
        return 0
    else
        fail "XOR Test Failed" "0x3C" "$result"
        return 1
    fi
}

# Test XOR with same values (should be 0)
test_xor_same() {
    local contract_addr="0x0000000000000000000000000000000000000019"
    # Bytecode: PUSH1 0x55, PUSH1 0x55, XOR, STOP
    redis-cli SET "$contract_addr" "60 55 60 55 18 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "XOR Same Test Passed: 0x55 XOR 0x55 = 0x00 ($result)"
        return 0
    else
        fail "XOR Same Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test BYTE opcode (0x1A) - Extract byte from word
test_byte() {
    local contract_addr="0x000000000000000000000000000000000000001A"
    # Bytecode: PUSH2 0x1234, PUSH1 31, BYTE, STOP
    # Extract byte 31 from 0x1234 (should be 0x34 - least significant byte)
    redis-cli SET "$contract_addr" "61 12 34 60 1F 1A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x34" ]; then
        success "BYTE Test Passed: byte 31 of 0x1234 = 0x34 ($result)"
        return 0
    else
        fail "BYTE Test Failed" "0x34" "$result"
        return 1
    fi
}

# Test BYTE with out of bounds index
test_byte_out_of_bounds() {
    local contract_addr="0x000000000000000000000000000000000000001B"
    # Bytecode: PUSH1 0xFF, PUSH1 32, BYTE, STOP
    # Index 32 is out of bounds, should return 0
    redis-cli SET "$contract_addr" "60 FF 60 20 1A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "BYTE Out-of-Bounds Test Passed: byte 32 = 0x00 ($result)"
        return 0
    else
        fail "BYTE Out-of-Bounds Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test SHL opcode (0x1B) - Left bit shift
test_shl() {
    local contract_addr="0x000000000000000000000000000000000000001C"
    # Bytecode: PUSH1 0x05, PUSH1 2, SHL, STOP
    # Stack: [2, 0x05] -> SHL pops shift=2, value=0x05 -> 0x05 << 2 = 0x14 (5 << 2 = 20)
    redis-cli SET "$contract_addr" "60 05 60 02 1B 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x14" ]; then
        success "SHL Test Passed: 0x05 << 2 = 0x14 ($result)"
        return 0
    else
        fail "SHL Test Failed" "0x14" "$result"
        return 1
    fi
}

# Test SHL with large shift (should be 0)
test_shl_large_shift() {
    local contract_addr="0x000000000000000000000000000000000000001D"
    # Bytecode: PUSH1 0x05, PUSH2 0x0100, SHL, STOP
    # Stack: [0x0100, 0x05] -> SHL pops shift=0x0100, value=0x05 -> 0x05 << 256 = 0 (shift too large)
    redis-cli SET "$contract_addr" "60 05 61 01 00 1B 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "SHL Large Shift Test Passed: 0x05 << 256 = 0x00 ($result)"
        return 0
    else
        fail "SHL Large Shift Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test SAR opcode (0x1D) - Arithmetic right shift
test_sar() {
    local contract_addr="0x000000000000000000000000000000000000001E"
    # Bytecode: PUSH1 0x14, PUSH1 2, SAR, STOP
    # Stack: [2, 0x14] -> SAR pops shift=2, value=0x14 -> 0x14 >> 2 = 0x05 (20 >> 2 = 5)
    redis-cli SET "$contract_addr" "60 14 60 02 1D 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x05" ]; then
        success "SAR Test Passed: 0x14 >> 2 = 0x05 ($result)"
        return 0
    else
        fail "SAR Test Failed" "0x05" "$result"
        return 1
    fi
}

# Test SAR with large shift on positive number
test_sar_large_shift_positive() {
    local contract_addr="0x000000000000000000000000000000000000001F"
    # Bytecode: PUSH1 0x14, PUSH2 0x0100, SAR, STOP
    # Stack: [0x0100, 0x14] -> SAR pops shift=0x0100, value=0x14 -> 0x14 >> 256 = 0 (positive number, large shift)
    redis-cli SET "$contract_addr" "60 14 61 01 00 1D 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "SAR Large Shift Positive Test Passed: 0x14 >> 256 = 0x00 ($result)"
        return 0
    else
        fail "SAR Large Shift Positive Test Failed" "0x00" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=8
    local passed_tests=0

    test_xor && ((passed_tests++))
    test_xor_same && ((passed_tests++))
    test_byte && ((passed_tests++))
    test_byte_out_of_bounds && ((passed_tests++))
    test_shl && ((passed_tests++))
    test_shl_large_shift && ((passed_tests++))
    test_sar && ((passed_tests++))
    test_sar_large_shift_positive && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Extended Bitwise Opcode Tests Passed!"
        exit 0
    else
        fail "Some Extended Bitwise Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main