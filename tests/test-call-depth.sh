#!/bin/bash

# Test call depth tracking

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "Call Depth Test..."
setup_redis

# Create a simple contract that just returns
CONTRACT_A="0x1111111111111111111111111111111111111111"
# Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE, PUSH1 0x20, PUSH1 0x00, RETURN
BYTECODE_A="0x604260005260206000F3"
redis-cli SET "CODE:${CONTRACT_A:2}" "$BYTECODE_A"

# Create a contract that calls CONTRACT_A
CONTRACT_B="0x2222222222222222222222222222222222222222"
# Bytecode: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 CONTRACT_A, PUSH2 0x1000, CALL, STOP
BYTECODE_B="0x60006000600060006000731111111111111111111111111111111111111111611000F100"
redis-cli SET "CODE:${CONTRACT_B:2}" "$BYTECODE_B"
redis-cli SET "$CONTRACT_B" "$BYTECODE_B"

echo "Test 1: Simple nested call"
redis-cli SET "CALLER" "0x0000000000000000000000000000000000000000"
redis-cli SET "CALLVALUE" "0"
redis-cli SET "CALLDATA" "0x"

RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT_B")
echo "Result: $RESULT"

if [ "$RESULT" = "0x01" ]; then
    echo "✓ Nested call succeeded"
else
    echo "✗ Nested call failed - expected 0x01, got $RESULT"
fi

# Now test recursive calls
echo ""
echo "Test 2: Recursive call (should hit depth limit)"

# Create a contract that calls itself
RECURSIVE_CONTRACT="0x3333333333333333333333333333333333333333"
# Bytecode: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, ADDRESS, PUSH2 0x1000, CALL, STOP
RECURSIVE_BYTECODE="0x6000600060006000600030611000F100"
redis-cli SET "CODE:${RECURSIVE_CONTRACT:2}" "$RECURSIVE_BYTECODE"
redis-cli SET "$RECURSIVE_CONTRACT" "$RECURSIVE_BYTECODE"

RESULT=$(redis-cli FCALL eth_call 1 "$RECURSIVE_CONTRACT")
echo "Recursive result: $RESULT"

# The result should be 0 because the innermost call will fail and return 0
if [ "$RESULT" = "0x00" ]; then
    echo "✓ Recursive call hit depth limit"
else
    echo "✗ Recursive call didn't hit depth limit - expected 0x00, got $RESULT"
fi
