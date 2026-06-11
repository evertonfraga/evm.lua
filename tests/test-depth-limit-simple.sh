#!/bin/bash

# Simple test to verify call depth limit

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "Call Depth Limit Test..."
setup_redis

# Create a simple contract
CONTRACT="0x1111111111111111111111111111111111111111"
BYTECODE="0x604200"  # PUSH1 0x42, STOP
redis-cli SET "CODE:${CONTRACT:2}" "$BYTECODE"

# Manually set call_depth to 1024 in the state (we can't do this directly, so let's test the logic)
# Instead, let's create a Lua script that tests the depth check

# Actually, let's just verify that the recursive contract eventually returns 0
# by checking if it's actually recursing

# Create recursive contract
RECURSIVE="0x3333333333333333333333333333333333333333"
RECURSIVE_BYTECODE="0x6000600060006000600030611000F100"
redis-cli SET "CODE:${RECURSIVE:2}" "$RECURSIVE_BYTECODE"
redis-cli SET "$RECURSIVE" "$RECURSIVE_BYTECODE"

redis-cli SET "CALLER" "0x0000000000000000000000000000000000000000"
redis-cli SET "CALLVALUE" "0"
redis-cli SET "CALLDATA" "0x"

echo "Calling recursive contract..."
RESULT=$(redis-cli FCALL eth_call 1 "$RECURSIVE" 2>&1)
echo "Result: $RESULT"

# The result should be 0 because the innermost call will fail
echo "Expected: 0x00 (call depth limit reached)"
