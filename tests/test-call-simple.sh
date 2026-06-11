#!/bin/bash

# Simple test for CALL opcode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "Simple CALL Test..."
setup_redis

# Setup: Create a simple contract that returns 42
CONTRACT_A="0x1111111111111111111111111111111111111111"
# Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE, PUSH1 0x20, PUSH1 0x00, RETURN
# 6042 6000 52 6020 6000 F3
BYTECODE_A="0x604260005260206000F3"

redis-cli SET "CODE:${CONTRACT_A:2}" "$BYTECODE_A"
echo "Contract A code set: $BYTECODE_A"

# Test calling an EOA (no code)
echo ""
echo "Test 1: Call to EOA (no code)"
EOA_ADDRESS="0x9999999999999999999999999999999999999999"

# Bytecode: PUSH1 0x00 (retLength), PUSH1 0x00 (retOffset), PUSH1 0x00 (argsLength), PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH20 EOA_ADDRESS, PUSH2 0x1000 (gas), CALL, STOP
# 6000 6000 6000 6000 6000 73<20 bytes> 611000 F1 00
TEST_BYTECODE="0x60006000600060006000739999999999999999999999999999999999999999611000F100"

CALLER_CONTRACT="0x2222222222222222222222222222222222222222"
redis-cli SET "$CALLER_CONTRACT" "$TEST_BYTECODE"
redis-cli SET "CALLER" "0x0000000000000000000000000000000000000000"
redis-cli SET "CALLVALUE" "0"
redis-cli SET "CALLDATA" "0x"

RESULT=$(redis-cli FCALL eth_call 1 "$CALLER_CONTRACT")
echo "Result: $RESULT"

if [ "$RESULT" = "0x01" ]; then
    echo "✓ Call to EOA succeeded"
else
    echo "✗ Call to EOA failed - expected 0x01, got $RESULT"
fi

echo ""
echo "Test 2: Call to contract with code"

# Bytecode to call CONTRACT_A
# PUSH1 0x20 (retLength), PUSH1 0x00 (retOffset), PUSH1 0x00 (argsLength), PUSH1 0x00 (argsOffset), PUSH1 0x00 (value), PUSH20 CONTRACT_A, PUSH2 0x1000 (gas), CALL, STOP
TEST_BYTECODE2="0x60206000600060006000731111111111111111111111111111111111111111611000F100"

redis-cli SET "$CALLER_CONTRACT" "$TEST_BYTECODE2"

RESULT=$(redis-cli FCALL eth_call 1 "$CALLER_CONTRACT")
echo "Result: $RESULT"

if [ "$RESULT" = "0x01" ]; then
    echo "✓ Call to contract succeeded"
else
    echo "✗ Call to contract failed - expected 0x01, got $RESULT"
fi
