#!/bin/bash

# Source library functions
source ./lib.sh

# Test ADDRESS opcode (0x30)
test_address() {
    local contract_addr="0x1234567890123456789012345678901234567890"
    # Bytecode: ADDRESS, STOP
    redis-cli SET "$contract_addr" "30 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "$contract_addr" ]; then
        success "ADDRESS Test Passed: Returns contract address"
        return 0
    else
        fail "ADDRESS Test Failed" "$contract_addr" "$result"
        return 1
    fi
}

# Test CALLER opcode (0x33)
test_caller() {
    local contract_addr="0x0000000000000000000000000000000000000070"
    local caller_addr="0xABCDEF1234567890ABCDEF1234567890ABCDEF12"
    
    # Set caller in Redis
    redis-cli SET "CALLER" "$caller_addr"
    
    # Bytecode: CALLER, STOP
    redis-cli SET "$contract_addr" "33 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "$caller_addr" ]; then
        success "CALLER Test Passed: Returns caller address"
        return 0
    else
        fail "CALLER Test Failed" "$caller_addr" "$result"
        return 1
    fi
}

# Test CALLVALUE opcode (0x34)
test_callvalue() {
    local contract_addr="0x0000000000000000000000000000000000000071"
    local call_value="1000000000000000000"  # 1 ETH in wei
    
    # Set call value in Redis
    redis-cli SET "CALLVALUE" "$call_value"
    
    # Bytecode: CALLVALUE, STOP
    redis-cli SET "$contract_addr" "34 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0xDE0B6B3A7640000" ]; then  # 1 ETH in hex
        success "CALLVALUE Test Passed: Returns call value"
        return 0
    else
        fail "CALLVALUE Test Failed" "0xDE0B6B3A7640000" "$result"
        return 1
    fi
}

# Test GASPRICE opcode (0x3A)
test_gasprice() {
    local contract_addr="0x0000000000000000000000000000000000000072"
    local gas_price="20000000000"  # 20 gwei
    
    # Set gas price in Redis
    redis-cli SET "GASPRICE" "$gas_price"
    
    # Bytecode: GASPRICE, STOP
    redis-cli SET "$contract_addr" "3A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x4A817C800" ]; then  # 20 gwei in hex
        success "GASPRICE Test Passed: Returns gas price"
        return 0
    else
        fail "GASPRICE Test Failed" "0x4A817C800" "$result"
        return 1
    fi
}

# Test CHAINID opcode (0x46)
test_chainid() {
    local contract_addr="0x0000000000000000000000000000000000000073"
    local chain_id="1"  # Ethereum mainnet
    
    # Set chain ID in Redis
    redis-cli SET "CHAINID" "$chain_id"
    
    # Bytecode: CHAINID, STOP
    redis-cli SET "$contract_addr" "46 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x01" ]; then
        success "CHAINID Test Passed: Returns chain ID"
        return 0
    else
        fail "CHAINID Test Failed" "0x01" "$result"
        return 1
    fi
}

# Test NUMBER opcode (0x43)
test_number() {
    local contract_addr="0x0000000000000000000000000000000000000074"
    local block_number="12345678"
    
    # Set block number in Redis
    redis-cli SET "NUMBER" "$block_number"
    
    # Bytecode: NUMBER, STOP
    redis-cli SET "$contract_addr" "43 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0xBC614E" ]; then  # 12345678 in hex
        success "NUMBER Test Passed: Returns block number"
        return 0
    else
        fail "NUMBER Test Failed" "0xBC614E" "$result"
        return 1
    fi
}

# Test TIMESTAMP opcode (0x42)
test_timestamp() {
    local contract_addr="0x0000000000000000000000000000000000000075"
    local timestamp="1640995200"  # Jan 1, 2022 00:00:00 UTC
    
    # Set timestamp in Redis
    redis-cli SET "TIMESTAMP" "$timestamp"
    
    # Bytecode: TIMESTAMP, STOP
    redis-cli SET "$contract_addr" "42 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x61D4A000" ]; then  # timestamp in hex
        success "TIMESTAMP Test Passed: Returns block timestamp"
        return 0
    else
        fail "TIMESTAMP Test Failed" "0x61D4A000" "$result"
        return 1
    fi
}

# Test GAS opcode (0x5A)
test_gas() {
    local contract_addr="0x0000000000000000000000000000000000000076"
    local gas_limit="21000"
    
    # Set gas in Redis
    redis-cli SET "GAS" "$gas_limit"
    
    # Bytecode: GAS, STOP
    redis-cli SET "$contract_addr" "5A 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x5208" ]; then  # 21000 in hex
        success "GAS Test Passed: Returns available gas"
        return 0
    else
        fail "GAS Test Failed" "0x5208" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=8
    local passed_tests=0

    test_address && ((passed_tests++))
    test_caller && ((passed_tests++))
    test_callvalue && ((passed_tests++))
    test_gasprice && ((passed_tests++))
    test_chainid && ((passed_tests++))
    test_number && ((passed_tests++))
    test_timestamp && ((passed_tests++))
    test_gas && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Blockchain Context Tests Passed!"
        exit 0
    else
        fail "Some Blockchain Context Tests Failed"
        exit 1
    fi
}

# Run the main function
main