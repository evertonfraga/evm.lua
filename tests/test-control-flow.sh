#!/bin/bash

# Source library functions
source ./lib.sh

# Test JUMP opcode (0x56)
test_jump() {
    local contract_addr="0x0000000000000000000000000000000000000030"
    # Bytecode: PUSH1 6, JUMP, PUSH1 99, JUMPDEST, PUSH1 42, STOP
    # Should jump over PUSH1 99 and execute PUSH1 42
    redis-cli SET "$contract_addr" "60 06 56 60 63 5B 60 2A 00"
    
    echo $(redis-cli FCALL eth_call_debug 1 "$contract_addr")

    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "JUMP Test Passed: Jumped correctly to JUMPDEST, result = 42 (0x2A)"
        return 0
    else
        fail "JUMP Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test JUMPI opcode (0x57) - conditional jump (true condition)
test_jumpi_true() {
    local contract_addr="0x0000000000000000000000000000000000000031"
    # Bytecode: PUSH1 1, PUSH1 8, JUMPI, PUSH1 99, JUMPDEST, PUSH1 42, STOP
    # Condition is 1 (true), should jump over PUSH1 99
    redis-cli SET "$contract_addr" "60 01 60 08 57 60 63 5B 60 2A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "JUMPI (true) Test Passed: Conditional jump executed, result = 42 (0x2A)"
        return 0
    else
        fail "JUMPI (true) Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test JUMPI opcode (0x57) - conditional jump (false condition)
test_jumpi_false() {
    local contract_addr="0x0000000000000000000000000000000000000032"
    # Bytecode: PUSH1 0, PUSH1 8, JUMPI, PUSH1 99, STOP, JUMPDEST, PUSH1 42, STOP
    # Condition is 0 (false), should NOT jump, execute PUSH1 99, and stop
    redis-cli SET "$contract_addr" "60 00 60 08 57 60 63 00 5B 60 2A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x63" ]; then
        success "JUMPI (false) Test Passed: Conditional jump not executed, result = 99 (0x63)"
        return 0
    else
        fail "JUMPI (false) Test Failed" "0x63" "$result"
        return 1
    fi
}

# Test JUMPDEST opcode (0x5B) - valid jump destination
test_jumpdest() {
    local contract_addr="0x0000000000000000000000000000000000000033"
    # Bytecode: PUSH1 4, JUMP, JUMPDEST, PUSH1 42, STOP
    # Simple jump to JUMPDEST
    redis-cli SET "$contract_addr" "60 04 56 5B 60 2A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "JUMPDEST Test Passed: Valid jump destination, result = 42 (0x2A)"
        return 0
    else
        fail "JUMPDEST Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test STOP opcode (0x00)
test_stop() {
    local contract_addr="0x0000000000000000000000000000000000000034"
    # Bytecode: PUSH1 42, STOP, PUSH1 99 (should not execute PUSH1 99)
    redis-cli SET "$contract_addr" "60 2A 00 60 63"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "STOP Test Passed: Execution stopped correctly, result = 42 (0x2A)"
        return 0
    else
        fail "STOP Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Test complex control flow - loop-like structure
test_complex_control_flow() {
    local contract_addr="0x0000000000000000000000000000000000000035"
    # Bytecode: PUSH1 0A, JUMPDEST, PUSH1 01, SWAP1, SUB, DUP1, PUSH1 03, JUMPI, PUSH1 2A, STOP
    # This creates a countdown loop: start with 10, subtract 1 each iteration
    # When value reaches 0, JUMPI condition fails and we return 42 (0x2A)
    redis-cli SET "$contract_addr" "60 0A 5B 60 01 90 03 80 60 03 57 60 2A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x2A" ]; then
        success "Complex Control Flow Test Passed: result = 42 (0x2A)"
        return 0
    else
        fail "Complex Control Flow Test Failed" "0x2A" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=6
    local passed_tests=0

    test_jump && ((passed_tests++))
    test_jumpi_true && ((passed_tests++))
    test_jumpi_false && ((passed_tests++))
    test_jumpdest && ((passed_tests++))
    test_stop && ((passed_tests++))
    test_complex_control_flow && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Control Flow Opcode Tests Passed!"
        exit 0
    else
        fail "Some Control Flow Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main
