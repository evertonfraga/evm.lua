#!/bin/bash

# Test a single recursive call

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "Single Recursive Call Test..."
setup_redis

# Create a contract that calls itself once and returns the result
CONTRACT="0x3333333333333333333333333333333333333333"
# Bytecode: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, ADDRESS, PUSH2 0x1000, CALL, STOP
BYTECODE="0x6000600060006000600030611000F100"
redis-cli SET "CODE:${CONTRACT:2}" "$BYTECODE"
redis-cli SET "$CONTRACT" "$BYTECODE"

redis-cli SET "CALLER" "0x0000000000000000000000000000000000000000"
redis-cli SET "CALLVALUE" "0"
redis-cli SET "CALLDATA" "0x"

echo "Calling contract that calls itself once..."
RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT" 2>&1 | tail -1)
echo "Result: $RESULT"

# The result should be 1 because:
# - Initial call (depth 0) calls itself
# - Nested call (depth 1) calls itself  
# - Nested call (depth 2) calls itself
# - ... continues until depth 1024
# - At depth 1024, CALL returns 0
# - That 0 propagates back up

echo ""
echo "Expected: 0x00 (because innermost call at depth 1024 fails)"
echo "If we get 0x01, the recursion isn't happening or depth check isn't working"
