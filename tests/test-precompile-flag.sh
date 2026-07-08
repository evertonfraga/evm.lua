#!/bin/bash

# Test precompile feature flag

source ./lib.sh

echo "Testing Precompile Feature Flag..."

# Test with precompiles ENABLED (default)
test_precompiles_enabled() {
    local contract_addr="0x0000000000000000000000000000000000000300"
    
    # Load EVM with precompiles enabled (default)
    cat ../evm.lua | redis-cli -x FUNCTION LOAD REPLACE > /dev/null
    
    # Call identity precompile (0x04)
    # Store 0x42 in memory, call identity, check result
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 20 60 01 60 00 60 00 60 04 61 FF FF F1 60 20 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Should return 0x42 (precompile executed)
    if [[ "$result" == *"42"* ]]; then
        success "Precompiles ENABLED: Identity precompile executed successfully"
        return 0
    else
        fail "Precompiles ENABLED: Identity precompile failed" "contains 0x42" "$result"
        return 1
    fi
}

# Test with precompiles DISABLED
test_precompiles_disabled() {
    local contract_addr="0x0000000000000000000000000000000000000301"
    
    # Modify EVM to disable precompiles
    cat ../evm.lua | sed 's/EVM.ENABLE_PRECOMPILES = true/EVM.ENABLE_PRECOMPILES = false/' | redis-cli -x FUNCTION LOAD REPLACE > /dev/null
    
    # Call identity precompile (0x04) - should treat as EOA (no code)
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 20 60 01 60 00 60 00 60 04 61 FF FF F1 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Should return 1 (success) because 0x04 is treated as EOA with no code
    if [ "$result" = "0x01" ]; then
        success "Precompiles DISABLED: Call to 0x04 treated as EOA (no precompile execution)"
        return 0
    else
        fail "Precompiles DISABLED: Unexpected result" "0x01" "$result"
        return 1
    fi
}

# Test re-enabling precompiles
test_precompiles_reenabled() {
    local contract_addr="0x0000000000000000000000000000000000000302"
    
    # Reload EVM with precompiles enabled
    cat ../evm.lua | redis-cli -x FUNCTION LOAD REPLACE > /dev/null
    
    # Call identity precompile again
    redis-cli SET "$contract_addr" "60 42 60 00 53 60 01 60 20 60 01 60 00 60 00 60 04 61 FF FF F1 60 20 51 00"
    
    local result=$(redis-cli FCALL eth_call 1 "$contract_addr")
    
    # Should return 0x42 (precompile executed again)
    if [[ "$result" == *"42"* ]]; then
        success "Precompiles RE-ENABLED: Identity precompile works again"
        return 0
    else
        fail "Precompiles RE-ENABLED: Identity precompile failed" "contains 0x42" "$result"
        return 1
    fi
}

# Setup and run tests
setup_redis

echo ""
test_precompiles_enabled
test_precompiles_disabled
test_precompiles_reenabled

echo ""
echo "Precompile feature flag tests completed!"
