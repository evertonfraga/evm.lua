#!/bin/bash

# Source library functions
source ./lib.sh

# Test Redis key generation and validation for environmental context
test_redis_key_generation() {
    local contract_addr="0x0000000000000000000000000000000000000001"
    
    # Test script that uses the helper functions
    local test_script='
    local function balance_key(address)
        local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
        addr_str = addr_str:gsub("^0x", ""):lower()
        return "BALANCE:" .. addr_str
    end
    
    local function code_key(address)
        local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
        addr_str = addr_str:gsub("^0x", ""):lower()
        return "CODE:" .. addr_str
    end
    
    local function codehash_key(address)
        local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
        addr_str = addr_str:gsub("^0x", ""):lower()
        return "CODEHASH:" .. addr_str
    end
    
    local test_addr = "0x1234567890123456789012345678901234567890"
    local balance_k = balance_key(test_addr)
    local code_k = code_key(test_addr)
    local codehash_k = codehash_key(test_addr)
    
    return balance_k .. "|" .. code_k .. "|" .. codehash_k
    '
    
    local result=$(redis-cli EVAL "$test_script" 0)
    local expected="BALANCE:1234567890123456789012345678901234567890|CODE:1234567890123456789012345678901234567890|CODEHASH:1234567890123456789012345678901234567890"
    
    if [ "$result" = "$expected" ]; then
        success "Redis Key Generation Test Passed"
        return 0
    else
        fail "Redis Key Generation Test Failed" "$expected" "$result"
        return 1
    fi
}

# Test setting and getting environmental context data
test_environmental_data_storage() {
    local test_address="1234567890123456789012345678901234567890"
    local balance_key="BALANCE:$test_address"
    local origin_key="ORIGIN"
    local code_key="CODE:$test_address"
    
    # Set test data
    redis-cli SET "$balance_key" "1000000000000000000"  # 1 ETH in wei
    redis-cli SET "$origin_key" "0x0000000000000000000000000000000000000001"
    redis-cli SET "$code_key" "608060405234801561001057600080fd5b50"  # Sample bytecode
    
    # Verify data was stored correctly
    local balance=$(redis-cli GET "$balance_key")
    local origin=$(redis-cli GET "$origin_key")
    local code=$(redis-cli GET "$code_key")
    
    local tests_passed=0
    
    if [ "$balance" = "1000000000000000000" ]; then
        success "Balance storage test passed"
        ((tests_passed++))
    else
        fail "Balance storage test failed" "1000000000000000000" "$balance"
    fi
    
    if [ "$origin" = "0x0000000000000000000000000000000000000001" ]; then
        success "Origin storage test passed"
        ((tests_passed++))
    else
        fail "Origin storage test failed" "0x0000000000000000000000000000000000000001" "$origin"
    fi
    
    if [ "$code" = "608060405234801561001057600080fd5b50" ]; then
        success "Code storage test passed"
        ((tests_passed++))
    else
        fail "Code storage test failed" "608060405234801561001057600080fd5b50" "$code"
    fi
    
    if [ $tests_passed -eq 3 ]; then
        return 0
    else
        return 1
    fi
}

# Test Redis key validation
test_redis_key_validation() {
    local validation_script='
    local function validate_env_key(key, expected_prefix)
        if not key or type(key) ~= "string" then
            return false
        end
        
        if not key:match("^" .. expected_prefix .. ":") then
            return false
        end
        
        local address_part = key:sub(#expected_prefix + 2)
        if not address_part:match("^[0-9a-f]+$") then
            return false
        end
        
        return true
    end
    
    local valid_balance = validate_env_key("BALANCE:1234567890123456789012345678901234567890", "BALANCE")
    local invalid_balance = validate_env_key("BALANCE:INVALID_ADDRESS", "BALANCE")
    local valid_code = validate_env_key("CODE:abcdef1234567890123456789012345678901234", "CODE")
    local invalid_prefix = validate_env_key("WRONG:1234567890123456789012345678901234567890", "BALANCE")
    
    if valid_balance and not invalid_balance and valid_code and not invalid_prefix then
        return "PASS"
    else
        return "FAIL"
    end
    '
    
    local result=$(redis-cli EVAL "$validation_script" 0)
    
    if [ "$result" = "PASS" ]; then
        success "Redis Key Validation Test Passed"
        return 0
    else
        fail "Redis Key Validation Test Failed" "PASS" "$result"
        return 1
    fi
}

# Test environmental data retrieval with defaults
test_env_data_defaults() {
    # Clear any existing data
    redis-cli DEL "BALANCE:nonexistent"
    redis-cli DEL "ORIGIN"
    
    local default_test_script='
    local function get_env_data(key, default_value)
        local value = redis.call("GET", key)
        if value == nil or value == false then
            return default_value
        end
        return value
    end
    
    local balance = get_env_data("BALANCE:nonexistent", "0")
    local origin = get_env_data("ORIGIN", "0x0000000000000000000000000000000000000000")
    
    return balance .. "|" .. origin
    '
    
    local result=$(redis-cli EVAL "$default_test_script" 0)
    local expected="0|0x0000000000000000000000000000000000000000"
    
    if [ "$result" = "$expected" ]; then
        success "Environmental Data Defaults Test Passed"
        return 0
    else
        fail "Environmental Data Defaults Test Failed" "$expected" "$result"
        return 1
    fi
}

# Main test runner
main() {
    ensure_redis_running
    load_evm_function

    local total_tests=4
    local passed_tests=0

    test_redis_key_generation && ((passed_tests++))
    test_environmental_data_storage && ((passed_tests++))
    test_redis_key_validation && ((passed_tests++))
    test_env_data_defaults && ((passed_tests++))

    echo "Test Results: $passed_tests/$total_tests tests passed"

    if [ $passed_tests -eq $total_tests ]; then
        success "All Redis Schema Tests Passed!"
        exit 0
    else
        fail "Some Redis Schema Tests Failed"
        exit 1
    fi
}

# Run the main function
main