#!/bin/bash

# Source library functions
source ./lib.sh

# Setup test data for environmental context testing
setup_environmental_test_data() {
    echo "Setting up environmental context test data..."
    
    # Account balances (in wei)
    redis-cli SET "BALANCE:1234567890123456789012345678901234567890" "1000000000000000000"  # 1 ETH
    redis-cli SET "BALANCE:abcdefabcdefabcdefabcdefabcdefabcdefabcd" "500000000000000000"   # 0.5 ETH
    redis-cli SET "BALANCE:0000000000000000000000000000000000000000" "0"                   # Empty account
    redis-cli SET "BALANCE:ffffffffffffffffffffffffffffffffffffffff" "2000000000000000000" # 2 ETH
    
    # Transaction origin
    redis-cli SET "ORIGIN" "0x0000000000000000000000000000000000000001"
    
    # Contract code examples
    redis-cli SET "CODE:1234567890123456789012345678901234567890" "608060405234801561001057600080fd5b50"
    redis-cli SET "CODE:abcdefabcdefabcdefabcdefabcdefabcdefabcd" "6080604052348015600f57600080fd5b50"
    redis-cli SET "CODE:contractwithcode123456789012345678901234" "608060405260043610610041576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806360fe47b114610046575b600080fd5b"
    
    # Contract code hashes (pre-computed for testing)
    redis-cli SET "CODEHASH:1234567890123456789012345678901234567890" "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
    redis-cli SET "CODEHASH:abcdefabcdefabcdefabcdefabcdefabcdefabcd" "0xa1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456"
    
    # Block context data
    redis-cli SET "COINBASE" "0x0000000000000000000000000000000000000002"
    redis-cli SET "PREVRANDAO" "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    redis-cli SET "GASLIMIT" "30000000"
    redis-cli SET "BASEFEE" "20000000000"  # 20 gwei
    
    # Current contract address for SELFBALANCE testing
    redis-cli SET "BALANCE:currentcontract123456789012345678901234" "750000000000000000"  # 0.75 ETH
    
    echo "Environmental context test data setup complete!"
}

# Verify test data was set correctly
verify_test_data() {
    echo "Verifying test data..."
    
    local tests_passed=0
    local total_tests=0
    
    # Check balance data
    ((total_tests++))
    local balance=$(redis-cli GET "BALANCE:1234567890123456789012345678901234567890")
    if [ "$balance" = "1000000000000000000" ]; then
        success "Balance test data verified"
        ((tests_passed++))
    else
        fail "Balance test data verification failed" "1000000000000000000" "$balance"
    fi
    
    # Check origin data
    ((total_tests++))
    local origin=$(redis-cli GET "ORIGIN")
    if [ "$origin" = "0x0000000000000000000000000000000000000001" ]; then
        success "Origin test data verified"
        ((tests_passed++))
    else
        fail "Origin test data verification failed" "0x0000000000000000000000000000000000000001" "$origin"
    fi
    
    # Check code data
    ((total_tests++))
    local code=$(redis-cli GET "CODE:1234567890123456789012345678901234567890")
    if [ "$code" = "608060405234801561001057600080fd5b50" ]; then
        success "Code test data verified"
        ((tests_passed++))
    else
        fail "Code test data verification failed" "608060405234801561001057600080fd5b50" "$code"
    fi
    
    # Check block context data
    ((total_tests++))
    local coinbase=$(redis-cli GET "COINBASE")
    if [ "$coinbase" = "0x0000000000000000000000000000000000000002" ]; then
        success "Coinbase test data verified"
        ((tests_passed++))
    else
        fail "Coinbase test data verification failed" "0x0000000000000000000000000000000000000002" "$coinbase"
    fi
    
    ((total_tests++))
    local gaslimit=$(redis-cli GET "GASLIMIT")
    if [ "$gaslimit" = "30000000" ]; then
        success "Gas limit test data verified"
        ((tests_passed++))
    else
        fail "Gas limit test data verification failed" "30000000" "$gaslimit"
    fi
    
    echo "Verification Results: $tests_passed/$total_tests tests passed"
    
    if [ $tests_passed -eq $total_tests ]; then
        return 0
    else
        return 1
    fi
}

# Clean up test data
cleanup_test_data() {
    echo "Cleaning up environmental context test data..."
    
    # Remove balance data
    redis-cli DEL "BALANCE:1234567890123456789012345678901234567890"
    redis-cli DEL "BALANCE:abcdefabcdefabcdefabcdefabcdefabcdefabcd"
    redis-cli DEL "BALANCE:0000000000000000000000000000000000000000"
    redis-cli DEL "BALANCE:ffffffffffffffffffffffffffffffffffffffff"
    redis-cli DEL "BALANCE:currentcontract123456789012345678901234"
    
    # Remove origin data
    redis-cli DEL "ORIGIN"
    
    # Remove code data
    redis-cli DEL "CODE:1234567890123456789012345678901234567890"
    redis-cli DEL "CODE:abcdefabcdefabcdefabcdefabcdefabcdefabcd"
    redis-cli DEL "CODE:contractwithcode123456789012345678901234"
    
    # Remove code hash data
    redis-cli DEL "CODEHASH:1234567890123456789012345678901234567890"
    redis-cli DEL "CODEHASH:abcdefabcdefabcdefabcdefabcdefabcdefabcd"
    
    # Remove block context data
    redis-cli DEL "COINBASE"
    redis-cli DEL "PREVRANDAO"
    redis-cli DEL "GASLIMIT"
    redis-cli DEL "BASEFEE"
    
    echo "Test data cleanup complete!"
}

# Main function
main() {
    ensure_redis_running
    
    case "${1:-setup}" in
        "setup")
            setup_environmental_test_data
            verify_test_data
            ;;
        "verify")
            verify_test_data
            ;;
        "cleanup")
            cleanup_test_data
            ;;
        *)
            echo "Usage: $0 [setup|verify|cleanup]"
            echo "  setup   - Set up test data and verify (default)"
            echo "  verify  - Verify existing test data"
            echo "  cleanup - Remove all test data"
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"