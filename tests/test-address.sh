#!/bin/bash

# Test ADDRESS opcode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "ADDRESS Test..."
setup_redis

# Create a contract that just returns its address
CONTRACT="0x3333333333333333333333333333333333333333"
# Bytecode: ADDRESS, STOP
BYTECODE="0x3000"
redis-cli SET "$CONTRACT" "$BYTECODE"

redis-cli SET "CALLER" "0x0000000000000000000000000000000000000000"
redis-cli SET "CALLVALUE" "0"
redis-cli SET "CALLDATA" "0x"

RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT")
echo "ADDRESS result: $RESULT"
echo "Expected: $CONTRACT"
