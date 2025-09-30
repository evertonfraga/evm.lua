#!/bin/bash

# Source library functions
source ./lib.sh

# Test COINBASE opcode (0x41)
test_coinbase() {
    local contract_addr="0x0000000000000000000000000000000000000050"
    
    # Setup test data
    redis-cli SET "COINBASE" "0x1234567890123456789012345678901234567890"
    
    # Bytecode: COINBASE, STOP
    redis-cli SET "$contract_addr" "41 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x1234567890123456789012345678901234567890"
    
    if [ "$result" = "$expected" ]; then
        success "COINBASE Test Passed: Retrieved coinbase address ($result)"
        return 0
    else
        fail "COINBASE Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test COINBASE with default value
test_coinbase_default() {
    local contract_addr="0x0000000000000000000000000000000000000051"
    
    # Remove COINBASE from Redis to test default
    redis-cli DEL "COINBASE"
    
    # Bytecode: COINBASE, STOP
    redis-cli SET "$contract_addr" "41 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x0000000000000000000000000000000000000000"
    
    if [ "$result" = "$expected" ]; then
        success "COINBASE Default Test Passed: Retrieved default coinbase ($result)"
        return 0
    else
        fail "COINBASE Default Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test PREVRANDAO opcode (0x44)
test_prevrandao() {
    local contract_addr="0x0000000000000000000000000000000000000052"
    
    # Setup test data - 32-byte random value
    redis-cli SET "PREVRANDAO" "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    
    # Bytecode: PREVRANDAO, STOP
    redis-cli SET "$contract_addr" "44 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF"
    
    if [ "$result" = "$expected" ]; then
        success "PREVRANDAO Test Passed: Retrieved previous randomness ($result)"
        return 0
    else
        fail "PREVRANDAO Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test PREVRANDAO with default value
test_prevrandao_default() {
    local contract_addr="0x0000000000000000000000000000000000000053"
    
    # Remove PREVRANDAO from Redis to test default
    redis-cli DEL "PREVRANDAO"
    
    # Bytecode: PREVRANDAO, STOP
    redis-cli SET "$contract_addr" "44 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x0000000000000000000000000000000000000000000000000000000000000000"
    
    if [ "$result" = "$expected" ]; then
        success "PREVRANDAO Default Test Passed: Retrieved default randomness ($result)"
        return 0
    else
        fail "PREVRANDAO Default Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test GASLIMIT opcode (0x45)
test_gaslimit() {
    local contract_addr="0x0000000000000000000000000000000000000054"
    
    # Setup test data
    redis-cli SET "GASLIMIT" "15000000"  # 15M gas limit
    
    # Bytecode: GASLIMIT, STOP
    redis-cli SET "$contract_addr" "45 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0xE4E1C0"  # 15000000 in hex
    
    if [ "$result" = "$expected" ]; then
        success "GASLIMIT Test Passed: Retrieved gas limit of 15M ($result)"
        return 0
    else
        fail "GASLIMIT Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test GASLIMIT with default value
test_gaslimit_default() {
    local contract_addr="0x0000000000000000000000000000000000000055"
    
    # Remove GASLIMIT from Redis to test default
    redis-cli DEL "GASLIMIT"
    
    # Bytecode: GASLIMIT, STOP
    redis-cli SET "$contract_addr" "45 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x1C9C380"  # 30000000 in hex (default 30M)
    
    if [ "$result" = "$expected" ]; then
        success "GASLIMIT Default Test Passed: Retrieved default gas limit of 30M ($result)"
        return 0
    else
        fail "GASLIMIT Default Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test SELFBALANCE opcode (0x47)
test_selfbalance() {
    local contract_addr="0x0000000000000000000000000000000000000056"
    
    # Setup test data - set balance for the contract itself
    local balance_key="BALANCE:0000000000000000000000000000000000000056"
    redis-cli SET "$balance_key" "2500000000000000000"  # 2.5 ETH in wei
    
    # Bytecode: SELFBALANCE, STOP
    redis-cli SET "$contract_addr" "47 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x22B1C8C1227A0000"  # 2500000000000000000 in hex
    
    if [ "$result" = "$expected" ]; then
        success "SELFBALANCE Test Passed: Retrieved self balance of 2.5 ETH ($result)"
        return 0
    else
        fail "SELFBALANCE Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test SELFBALANCE with zero balance
test_selfbalance_zero() {
    local contract_addr="0x0000000000000000000000000000000000000057"
    
    # Setup test data - zero balance
    local balance_key="BALANCE:0000000000000000000000000000000000000057"
    redis-cli SET "$balance_key" "0"
    
    # Bytecode: SELFBALANCE, STOP
    redis-cli SET "$contract_addr" "47 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "SELFBALANCE Zero Test Passed: Retrieved zero balance ($result)"
        return 0
    else
        fail "SELFBALANCE Zero Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test SELFBALANCE with non-existent balance (should return 0)
test_selfbalance_nonexistent() {
    local contract_addr="0x0000000000000000000000000000000000000058"
    
    # Ensure no balance exists for this address
    local balance_key="BALANCE:0000000000000000000000000000000000000058"
    redis-cli DEL "$balance_key"
    
    # Bytecode: SELFBALANCE, STOP
    redis-cli SET "$contract_addr" "47 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    if [ "$result" = "0x00" ]; then
        success "SELFBALANCE Non-existent Test Passed: Retrieved zero for non-existent balance ($result)"
        return 0
    else
        fail "SELFBALANCE Non-existent Test Failed" "0x00" "$result"
        return 1
    fi
}

# Test BASEFEE opcode (0x48)
test_basefee() {
    local contract_addr="0x0000000000000000000000000000000000000059"
    
    # Setup test data
    redis-cli SET "BASEFEE" "25000000000"  # 25 gwei
    
    # Bytecode: BASEFEE, STOP
    redis-cli SET "$contract_addr" "48 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x5D21DBA00"  # 25000000000 in hex
    
    if [ "$result" = "$expected" ]; then
        success "BASEFEE Test Passed: Retrieved base fee of 25 gwei ($result)"
        return 0
    else
        fail "BASEFEE Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test BASEFEE with default value
test_basefee_default() {
    local contract_addr="0x0000000000000000000000000000000000000060"
    
    # Remove BASEFEE from Redis to test default
    redis-cli DEL "BASEFEE"
    
    # Bytecode: BASEFEE, STOP
    redis-cli SET "$contract_addr" "48 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x3B9ACA00"  # 1000000000 in hex (default 1 gwei)
    
    if [ "$result" = "$expected" ]; then
        success "BASEFEE Default Test Passed: Retrieved default base fee of 1 gwei ($result)"
        return 0
    else
        fail "BASEFEE Default Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test combination of block context opcodes
test_block_context_combination() {
    local contract_addr="0x0000000000000000000000000000000000000061"
    
    # Setup test data
    redis-cli SET "COINBASE" "0x1111111111111111111111111111111111111111"
    redis-cli SET "GASLIMIT" "12000000"  # 12M gas
    redis-cli SET "BASEFEE" "20000000000"  # 20 gwei
    
    # Bytecode: 
    # COINBASE, POP (just test that it executes)
    # GASLIMIT, POP
    # BASEFEE, STOP (leave basefee on stack)
    redis-cli SET "$contract_addr" "41 50 45 50 48 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    local expected="0x4A817C800"  # 20000000000 in hex
    
    if [ "$result" = "$expected" ]; then
        success "Block Context Combination Test Passed: All opcodes executed correctly ($result)"
        return 0
    else
        fail "Block Context Combination Test Failed" "$expected" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=12
    local passed_tests=0

    test_coinbase && ((passed_tests++))
    test_coinbase_default && ((passed_tests++))
    test_prevrandao && ((passed_tests++))
    test_prevrandao_default && ((passed_tests++))
    test_gaslimit && ((passed_tests++))
    test_gaslimit_default && ((passed_tests++))
    test_selfbalance && ((passed_tests++))
    test_selfbalance_zero && ((passed_tests++))
    test_selfbalance_nonexistent && ((passed_tests++))
    test_basefee && ((passed_tests++))
    test_basefee_default && ((passed_tests++))
    test_block_context_combination && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Block Context Opcode Tests Passed!"
        exit 0
    else
        fail "Some Block Context Opcode Tests Failed"
        exit 1
    fi
}

# Run the main function
main