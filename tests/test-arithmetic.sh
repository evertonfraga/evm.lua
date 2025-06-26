#!/bin/bash

# Source library functions
source ./lib.sh

# Test ADD opcode (0x01)
test_add() {
    local contract_addr="0x0000000000000000000000000000000000000001"
    # Bytecode: PUSH1 10, PUSH1 20, ADD, STOP
    redis-cli SET "$contract_addr" "60 0A 60 14 01 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "30" ]; then
        echo "✓ ADD Test Passed: 10 + 20 = 30"
        return 0
    else
        echo "✗ ADD Test Failed. Expected 30, Got $result"
        return 1
    fi
}

# Test SUB opcode (0x03)
test_sub() {
    local contract_addr="0x0000000000000000000000000000000000000003"
    # Bytecode: PUSH1 25, PUSH1 10, SUB, STOP
    redis-cli SET "$contract_addr" "60 0A 60 19 03 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "10" ]; then
        echo "✓ SUB Test Passed: 25 - 10 = 15"
        return 0
    else
        echo "✗ SUB Test Failed. Expected 15, Got $result"
        return 1
    fi
}

# Test MUL opcode (0x02)
test_mul() {
    local contract_addr="0x0000000000000000000000000000000000000002"
    # Bytecode: PUSH1 6, PUSH1 7, MUL, STOP
    redis-cli SET "$contract_addr" "60 06 60 07 02 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "42" ]; then
        echo "✓ MUL Test Passed: 6 * 7 = 42"
        return 0
    else
        echo "✗ MUL Test Failed. Expected 42, Got $result"
        return 1
    fi
}

# Test DIV opcode (0x04)
test_div() {
    local contract_addr="0x0000000000000000000000000000000000000004"
    # Bytecode: PUSH1 20, PUSH1 5, DIV, STOP
    redis-cli SET "$contract_addr" "60 14 60 05 04 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "4" ]; then
        echo "✓ DIV Test Passed: 20 / 5 = 4"
        return 0
    else
        echo "✗ DIV Test Failed. Expected 4, Got $result"
        return 1
    fi
}

# Test SDIV opcode (0x05)
test_sdiv() {
    local contract_addr="0x0000000000000000000000000000000000000005"
    # Bytecode: PUSH1 20, PUSH1 5, SDIV, STOP
    redis-cli SET "$contract_addr" "60 14 60 05 05 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "4" ]; then
        echo "✓ SDIV Test Passed: 20 / 5 = 4"
        return 0
    else
        echo "✗ SDIV Test Failed. Expected 4, Got $result"
        return 1
    fi
}

# Main test runner
main() {

    local total_tests=5
    local passed_tests=0

    test_add && ((passed_tests++))
    test_sub && ((passed_tests++))
    test_mul && ((passed_tests++))
    test_div && ((passed_tests++))
    test_sdiv && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        echo "✓ All Arithmetic Opcode Tests Passed!"
        exit 0
    else
        echo "✗ Some Arithmetic Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main
