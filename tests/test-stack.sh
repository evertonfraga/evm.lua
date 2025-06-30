#!/bin/bash

# Source library functions
source ./lib.sh

# Test POP opcode (0x50)
test_pop() {
    local contract_addr="0x0000000000000000000000000000000000000020"
    # Bytecode: PUSH1 42, PUSH1 10, POP, STOP (should leave 42 on stack)
    redis-cli SET "$contract_addr" "60 2A 60 0A 50 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "POP Test Passed: Stack top after POP = 42 (0x2A)"
        return 0
    else
        fail "POP Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test PUSH0 opcode (0x5F)
test_push0() {
    local contract_addr="0x0000000000000000000000000000000000000021"
    # Bytecode: PUSH0, STOP (should push 0 onto stack)
    redis-cli SET "$contract_addr" "5F 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "PUSH0 Test Passed: PUSH0 pushes 0 (0x00)"
        return 0
    else
        fail "PUSH0 Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test PUSH1 opcode (0x60)
test_push1() {
    local contract_addr="0x0000000000000000000000000000000000000022"
    # Bytecode: PUSH1 0xFF, STOP
    redis-cli SET "$contract_addr" "60 FF 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0xFF" ]; then
        success "PUSH1 Test Passed: PUSH1 0xFF = 255 (0xFF)"
        return 0
    else
        fail "PUSH1 Test Failed" "0xFF" "$result"
        return 1
    fi
}

# Test PUSH2 opcode (0x61)
test_push2() {
    local contract_addr="0x0000000000000000000000000000000000000023"
    # Bytecode: PUSH2 0x1234, STOP
    redis-cli SET "$contract_addr" "61 12 34 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # 0x1234 = 4660 in decimal
    local expected_hex="0x1234"
    if [ "$result" = "$expected_hex" ]; then
        success "PUSH2 Test Passed: PUSH2 0x1234 = $result"
        return 0
    else
        fail "PUSH2 Test Failed" "$expected_hex" "$result"
        return 1
    fi
}

# Test PUSH3 opcode (0x62)
test_push3() {
    local contract_addr="0x0000000000000000000000000000000000000024"
    # Bytecode: PUSH3 0x123456, STOP
    redis-cli SET "$contract_addr" "62 12 34 56 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # 0x123456 = 1193046 in decimal
    local expected_hex="0x123456"
    if [ "$result" = "$expected_hex" ]; then
        success "PUSH3 Test Passed: PUSH3 0x123456 = $result"
        return 0
    else
        fail "PUSH3 Test Failed" "$expected_hex" "$result"
        return 1
    fi
}

# Test PUSH4 opcode (0x63)
test_push4() {
    local contract_addr="0x000000000000000000000000000000000000003A"
    redis-cli SET "$contract_addr" "63 12 34 56 78 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x12345678" ]; then
        success "PUSH4 Test Passed: PUSH4 0x12345678 = $result"
        return 0
    else
        fail "PUSH4 Test Failed" "0x12345678" "$result"
        return 1
    fi
}

# Test PUSH4 opcode (0x63) - more bytes
test_push5() {
    local contract_addr="0x000000000000000000000000000000000000003B"
    redis-cli SET "$contract_addr" "64 12 34 56 78 9A 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x123456789A" ]; then
        success "PUSH5 Test Passed: PUSH5 works correctly"
        return 0
    else
        fail "PUSH5 Test Failed" "0x123456789A" "$result"
        return 1
    fi
}

# Test PUSH6 opcode (0x65)
test_push6() {
    local contract_addr="0x000000000000000000000000000000000000003C"
    redis-cli SET "$contract_addr" "65 12 34 56 78 9A BC 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x123456789ABC" ]; then
        success "PUSH6 Test Passed: PUSH6 works correctly"
        return 0
    else
        fail "PUSH6 Test Failed" "0x123456789ABC" "$result"
        return 1
    fi
}

# Test PUSH7 opcode (0x66)
test_push7() {
    local contract_addr="0x000000000000000000000000000000000000003D"
    redis-cli SET "$contract_addr" "66 12 34 56 78 9A BC DE 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x123456789ABCDE" ]; then
        success "PUSH7 Test Passed: PUSH7 works correctly"
        return 0
    else
        fail "PUSH7 Test Failed" "0x123456789ABCDE" "$result"
        return 1
    fi
}

# Test PUSH8 opcode (0x67) - Maximum 8-byte value
test_push8() {
    local contract_addr="0x000000000000000000000000000000000000003E"
    # PUSH8 with all FF bytes - tests maximum 8-byte value (2^64 - 1)
    redis-cli SET "$contract_addr" "67 FF FF FF FF FF FF FF FF 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [[ "$result" = "0xFFFFFFFFFFFFFFFF" ]]; then
        success "PUSH8 Test Passed: PUSH8 handles max 8-byte value"
        return 0
    else
        fail "PUSH8 Test Failed" "0xFFFFFFFFFFFFFFFF" "$result"
        return 1
    fi
}

# Test PUSH16 opcode (0x6F) - Maximum 16-byte value
test_push16() {
    local contract_addr="0x000000000000000000000000000000000000003F"
    # PUSH16 with all FF bytes - tests maximum 16-byte value (2^128 - 1)
    redis-cli SET "$contract_addr" "6F FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [[ "$result" = "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" ]]; then
        success "PUSH16 Test Passed: PUSH16 handles max 16-byte value"
        return 0
    else
        fail "PUSH16 Test Failed" "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" "$result"
        return 1
    fi
}

# Test PUSH32 opcode (0x7F)
test_push32() {
    local contract_addr="0x0000000000000000000000000000000000000040"
    # Simple PUSH32 with mostly zeros to avoid overflow
    redis-cli SET "$contract_addr" "7F 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 42 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x42" ]; then 
        success "PUSH32 Test Passed: PUSH32 pushes 32-byte value (0x42)"
        return 0
    else
        fail "PUSH32 Test Failed" "0x42" "$result"
        return 1
    fi
}

# Test PUSH32 with all FF bytes
test_push32_ff() {
    local contract_addr="0x0000000000000000000000000000000000000041"
    # PUSH32 with all FF bytes - tests maximum value handling
    redis-cli SET "$contract_addr" "7F FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")

    if [[ "$result" = "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" ]]; then
        success "PUSH32 FF Test Passed: PUSH32 handles max value correctly"
        return 0
    else
        fail "PUSH32 FF Test Failed" "0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" "$result"
        return 1
    fi
}

# Test DUP1 opcode (0x80)
test_dup1() {
    local contract_addr="0x0000000000000000000000000000000000000025"
    # Bytecode: PUSH1 42, DUP1, POP, STOP (duplicate top, then pop duplicate, leaving original)
    redis-cli SET "$contract_addr" "60 2A 80 50 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "DUP1 Test Passed: DUP1 duplicates stack top correctly"
        return 0
    else
        fail "DUP1 Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test DUP2 opcode (0x81)
test_dup2() {
    local contract_addr="0x0000000000000000000000000000000000000026"
    # Bytecode: PUSH1 10, PUSH1 20, DUP2, STOP (should duplicate second item, result should be 10)
    redis-cli SET "$contract_addr" "60 0A 60 14 81 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x0A" ]; then
        success "DUP2 Test Passed: DUP2 duplicates second stack item correctly"
        return 0
    else
        fail "DUP2 Test Failed" "0x0A" "$result"
        return 1
    fi
}

# Test DUP3-DUP16 opcodes (0x82-0x8F)
test_dup3() {
    local contract_addr="0x0000000000000000000000000000000000000037"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 82 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "DUP3 Test Passed: DUP3 duplicates correctly"
        return 0
    else
        fail "DUP3 Test Failed" "0x01" "$result"
        return 1
    fi
}

test_dup4() {
    local contract_addr="0x0000000000000000000000000000000000000038"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 83 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "DUP4 Test Passed: DUP4 duplicates correctly"
        return 0
    else
        fail "DUP4 Test Failed" "0x01" "$result"
        return 1
    fi
}

test_dup16() {
    local contract_addr="0x0000000000000000000000000000000000000039"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 60 0D 60 0E 60 0F 60 10 8F 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "DUP16 Test Passed: DUP16 duplicates correctly"
        return 0
    else
        fail "DUP16 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP1 opcode (0x90)
test_swap1() {
    local contract_addr="0x0000000000000000000000000000000000000027"
    # Bytecode: PUSH1 10, PUSH1 20, SWAP1, STOP (should swap top two, result should be 10)
    redis-cli SET "$contract_addr" "60 0A 60 14 90 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    echo $result
    
    if [ "$result" = "0x0A" ]; then
        success "SWAP1 Test Passed: SWAP1 swaps top two stack items correctly"
        return 0
    else
        fail "SWAP1 Test Failed" "0x0A" "$result"
        return 1
    fi
}

# Test SWAP2 opcode (0x91)
test_swap2() {
    local contract_addr="0x0000000000000000000000000000000000000028"
    # Bytecode: PUSH1 5, PUSH1 10, PUSH1 20, SWAP2, STOP (should swap top with third, result should be 5)
    redis-cli SET "$contract_addr" "60 05 60 0A 60 14 91 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x05" ]; then
        success "SWAP2 Test Passed: SWAP2 swaps correctly"
        return 0
    else
        fail "SWAP2 Test Failed" "0x05" "$result"
        return 1
    fi
}

# Test SWAP3 opcode (0x92)
test_swap3() {
    local contract_addr="0x0000000000000000000000000000000000000029"
    # Bytecode: PUSH1 1, PUSH1 2, PUSH1 3, PUSH1 4, SWAP3, STOP 
    # Stack before SWAP3: [1, 2, 3, 4] (4 on top)
    # SWAP3 swaps top (4) with 4th element (1)
    # Stack after SWAP3: [4, 2, 3, 1] (1 on top)
    # Result should be 1 (0x01)
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 92 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "SWAP3 Test Passed: SWAP3 swaps top with 4th element correctly"
        return 0
    else
        fail "SWAP3 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP4 opcode (0x93)
test_swap4() {
    local contract_addr="0x000000000000000000000000000000000000002A"
    # Bytecode: PUSH1 1, PUSH1 2, PUSH1 3, PUSH1 4, PUSH1 5, SWAP4, STOP
    # Stack before SWAP4: [1, 2, 3, 4, 5] (5 on top)
    # SWAP4 swaps top (5) with 5th element (1)
    # Stack after SWAP4: [5, 2, 3, 4, 1] (1 on top)
    # Result should be 1 (0x01)
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 93 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "SWAP4 Test Passed: SWAP4 swaps top with 5th element correctly"
        return 0
    else
        fail "SWAP4 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP5 opcode (0x94)
test_swap5() {
    local contract_addr="0x000000000000000000000000000000000000002B"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 94 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP5 Test Passed: SWAP5 swaps correctly"
        return 0
    else
        fail "SWAP5 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP6 opcode (0x95)
test_swap6() {
    local contract_addr="0x000000000000000000000000000000000000002C"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 95 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP6 Test Passed: SWAP6 swaps correctly"
        return 0
    else
        fail "SWAP6 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP7 opcode (0x96)
test_swap7() {
    local contract_addr="0x000000000000000000000000000000000000002D"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 96 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP7 Test Passed: SWAP7 swaps correctly"
        return 0
    else
        fail "SWAP7 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP8 opcode (0x97)
test_swap8() {
    local contract_addr="0x000000000000000000000000000000000000002E"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 97 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP8 Test Passed: SWAP8 swaps correctly"
        return 0
    else
        fail "SWAP8 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP9 opcode (0x98)
test_swap9() {
    local contract_addr="0x000000000000000000000000000000000000002F"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 98 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP9 Test Passed: SWAP9 swaps correctly"
        return 0
    else
        fail "SWAP9 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP10 opcode (0x99)
test_swap10() {
    local contract_addr="0x0000000000000000000000000000000000000030"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 99 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP10 Test Passed: SWAP10 swaps correctly"
        return 0
    else
        fail "SWAP10 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP11 opcode (0x9A)
test_swap11() {
    local contract_addr="0x0000000000000000000000000000000000000031"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 9A 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP11 Test Passed: SWAP11 swaps correctly"
        return 0
    else
        fail "SWAP11 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP12 opcode (0x9B)
test_swap12() {
    local contract_addr="0x0000000000000000000000000000000000000032"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 60 0D 9B 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP12 Test Passed: SWAP12 swaps correctly"
        return 0
    else
        fail "SWAP12 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP13 opcode (0x9C)
test_swap13() {
    local contract_addr="0x0000000000000000000000000000000000000033"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 60 0D 60 0E 9C 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP13 Test Passed: SWAP13 swaps correctly"
        return 0
    else
        fail "SWAP13 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP14 opcode (0x9D)
test_swap14() {
    local contract_addr="0x0000000000000000000000000000000000000034"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 60 0D 60 0E 60 0F 9D 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP14 Test Passed: SWAP14 swaps correctly"
        return 0
    else
        fail "SWAP14 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP15 opcode (0x9E)
test_swap15() {
    local contract_addr="0x0000000000000000000000000000000000000035"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 60 0D 60 0E 60 0F 60 10 9E 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP15 Test Passed: SWAP15 swaps correctly"
        return 0
    else
        fail "SWAP15 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test SWAP16 opcode (0x9F)
test_swap16() {
    local contract_addr="0x0000000000000000000000000000000000000036"
    redis-cli SET "$contract_addr" "60 01 60 02 60 03 60 04 60 05 60 06 60 07 60 08 60 09 60 0A 60 0B 60 0C 60 0D 60 0E 60 0F 60 10 60 11 9F 00"
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    if [ "$result" = "0x01" ]; then
        success "SWAP16 Test Passed: SWAP16 swaps correctly"
        return 0
    else
        fail "SWAP16 Test Failed" "0x01" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=34
    local passed_tests=0

    test_pop && ((passed_tests++))
    test_push0 && ((passed_tests++))
    test_push1 && ((passed_tests++))
    test_push2 && ((passed_tests++))
    test_push3 && ((passed_tests++))
    test_push4 && ((passed_tests++))
    test_push5 && ((passed_tests++))
    test_push6 && ((passed_tests++))
    test_push7 && ((passed_tests++))
    test_push8 && ((passed_tests++))
    test_push16 && ((passed_tests++))
    test_push32 && ((passed_tests++))
    test_push32_ff && ((passed_tests++))
    test_dup1 && ((passed_tests++))
    test_dup2 && ((passed_tests++))
    test_dup3 && ((passed_tests++))
    test_dup4 && ((passed_tests++))
    test_dup16 && ((passed_tests++))
    test_swap1 && ((passed_tests++))
    test_swap2 && ((passed_tests++))
    test_swap3 && ((passed_tests++))
    test_swap4 && ((passed_tests++))
    test_swap5 && ((passed_tests++))
    test_swap6 && ((passed_tests++))
    test_swap7 && ((passed_tests++))
    test_swap8 && ((passed_tests++))
    test_swap9 && ((passed_tests++))
    test_swap10 && ((passed_tests++))
    test_swap11 && ((passed_tests++))
    test_swap12 && ((passed_tests++))
    test_swap13 && ((passed_tests++))
    test_swap14 && ((passed_tests++))
    test_swap15 && ((passed_tests++))
    test_swap16 && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Stack and Memory Opcode Tests Passed!"
        exit 0
    else
        fail "Some Stack and Memory Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main
