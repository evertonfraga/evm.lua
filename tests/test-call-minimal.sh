#!/bin/bash

# Minimal test for CALL opcode - just check if it returns success

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "Minimal CALL Test..."
setup_redis

# Test 1: Call to EOA (no code) - should return 1 (success)
echo "Test 1: Call to EOA"

# Simple bytecode: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 address, PUSH2 gas, CALL, STOP
# This pushes the CALL result (1 or 0) onto the stack and stops
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
