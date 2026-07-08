#!/bin/bash

# Test PC and MSIZE opcodes

source ./lib.sh

# Test PC opcode (0x58) - Program counter
test_pc() {
    local contract_addr="0x0000000000000000000000000000000000000058"
    # Bytecode: PC, STOP
    # PC should return the position of the PC instruction (0)
    redis-cli SET "$contract_addr" "58 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "PC Test Passed: PC at position 0 = 0x00 ($result)"
        return 0
    else
        fail "PC Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test PC opcode with offset
test_pc_offset() {
    local contract_addr="0x0000000000000000000000000000000000000059"
    # Bytecode: PUSH1 0x42, PC, STOP
    # PC should return the position of the PC instruction (2)
    redis-cli SET "$contract_addr" "60 42 58 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x02" ]; then
        success "PC Offset Test Passed: PC at position 2 = 0x02 ($result)"
        return 0
    else
        fail "PC Offset Test Failed" "0x02" "$result"
        return 1
    fi
}

# Test MSIZE opcode (0x59) - Memory size with empty memory
test_msize_empty() {
    local contract_addr="0x000000000000000000000000000000000000005A"
    # Bytecode: MSIZE, STOP
    # MSIZE should return 0 for empty memory
    redis-cli SET "$contract_addr" "59 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "MSIZE Empty Test Passed: Empty memory size = 0x00 ($result)"
        return 0
    else
        fail "MSIZE Empty Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test MSIZE opcode after memory store
test_msize_after_store() {
    local contract_addr="0x000000000000000000000000000000000000005B"
    # Bytecode: PUSH1 0xFF, PUSH1 0x10, MSTORE8, MSIZE, STOP
    # Store byte 0xFF at memory position 0x10, then check memory size
    redis-cli SET "$contract_addr" "60 FF 60 10 53 59 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x11" ]; then
        success "MSIZE After Store Test Passed: Memory size after storing at 0x10 = 0x11 ($result)"
        return 0
    else
        fail "MSIZE After Store Test Failed" "0x11" "$result"
        return 1
    fi
}

# Test MSIZE opcode after 32-byte memory store
test_msize_after_mstore() {
    local contract_addr="0x000000000000000000000000000000000000005C"
    # Bytecode: PUSH1 0x1234, PUSH1 0x00, MSTORE, MSIZE, STOP
    # Store 32-byte value at memory position 0x00, then check memory size
    redis-cli SET "$contract_addr" "61 12 34 60 00 52 59 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x20" ]; then
        success "MSIZE After MSTORE Test Passed: Memory size after 32-byte store = 0x20 ($result)"
        return 0
    else
        fail "MSIZE After MSTORE Test Failed" "0x20" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=5
    local passed_tests=0

    test_pc && ((passed_tests++))
    test_pc_offset && ((passed_tests++))
    test_msize_empty && ((passed_tests++))
    test_msize_after_store && ((passed_tests++))
    test_msize_after_mstore && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All PC and MSIZE Opcode Tests Passed!"
        exit 0
    else
        fail "Some PC and MSIZE Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main