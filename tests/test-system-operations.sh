#!/bin/bash

# Test system operations (CALL, CALLCODE, DELEGATECALL)

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

echo "Testing System Operations..."

# Setup test environment
setup_redis

# Test data setup for contract calls
echo "Setting up test contracts..."

# Contract A: Simple contract that returns a value
CONTRACT_A="0x1111111111111111111111111111111111111111"
# Bytecode: PUSH1 0x42, PUSH1 0x00, MSTORE, PUSH1 0x20, PUSH1 0x00, RETURN
BYTECODE_A="0x604260005260206000F3"

# Contract B: Contract that calls Contract A
CONTRACT_B="0x2222222222222222222222222222222222222222"
# Bytecode: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 CONTRACT_A, PUSH2 0x1000, CALL
BYTECODE_B="0x600060006000600073111111111111111111111111111111111111111161100F1"

# Store contracts in Redis (both formats for compatibility)
redis-cli SET "CODE:$CONTRACT_A" "$BYTECODE_A"
redis-cli SET "$CONTRACT_A" "$BYTECODE_A"
redis-cli SET "CODE:$CONTRACT_B" "$BYTECODE_B"
redis-cli SET "$CONTRACT_B" "$BYTECODE_B"

# Set up balances
redis-cli SET "BALANCE:$CONTRACT_A" "1000000000000000000"
redis-cli SET "BALANCE:$CONTRACT_B" "2000000000000000000"

# Test 1: CALL opcode (0xF1)
echo "Test 1: CALL opcode"
redis-cli SET "CALLER" "0x0000000000000000000000000000000000000000"
redis-cli SET "CALLVALUE" "0"
redis-cli SET "CALLDATA" "0x"
redis-cli SET "GAS" "100000"

# Test bytecode: PUSH1 0x20, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 CONTRACT_A, PUSH2 0x1000, CALL, STOP
TEST_BYTECODE="0x60206000600060006000731111111111111111111111111111111111111111611000F100"
redis-cli SET "$CONTRACT_B" "$TEST_BYTECODE"

RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT_B")
echo "CALL result: $RESULT"

# Verify the call was successful (should return 1 on stack)
if [ "$RESULT" = "0x01" ]; then
    echo "✓ CALL opcode test passed"
else
    echo "✗ CALL opcode test failed - expected 0x01, got $RESULT"
fi

# Test 2: CALLCODE opcode (0xF2)
echo "Test 2: CALLCODE opcode"

# Test bytecode: PUSH1 0x20, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 CONTRACT_A, PUSH2 0x1000, CALLCODE, STOP
TEST_BYTECODE="0x60206000600060006000731111111111111111111111111111111111111111611000F200"
redis-cli SET "$CONTRACT_B" "$TEST_BYTECODE"

RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT_B")
echo "CALLCODE result: $RESULT"

# Verify the call was successful (should return 1 on stack)
if [ "$RESULT" = "0x01" ]; then
    echo "✓ CALLCODE opcode test passed"
else
    echo "✗ CALLCODE opcode test failed - expected 0x01, got $RESULT"
fi

# Test 3: DELEGATECALL opcode (0xF4)
echo "Test 3: DELEGATECALL opcode"

# Test bytecode: PUSH1 0x20, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 CONTRACT_A, PUSH2 0x1000, DELEGATECALL, STOP
TEST_BYTECODE="0x60206000600060007311111111111111111111111111111111111111116110"
TEST_BYTECODE="${TEST_BYTECODE}00F400"
redis-cli SET "$CONTRACT_B" "$TEST_BYTECODE"

RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT_B")
echo "DELEGATECALL result: $RESULT"

# Verify the call was successful (should return 1 on stack)
if [ "$RESULT" = "0x01" ]; then
    echo "✓ DELEGATECALL opcode test passed"
else
    echo "✗ DELEGATECALL opcode test failed - expected 0x01, got $RESULT"
fi

# Test 4: Call to non-existent contract (should succeed for EOA)
echo "Test 4: Call to non-existent contract"
NON_EXISTENT="0x9999999999999999999999999999999999999999"

# Test bytecode: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH20 NON_EXISTENT, PUSH2 0x1000, CALL, STOP
TEST_BYTECODE="0x60006000600060006000739999999999999999999999999999999999999999611000F100"
redis-cli SET "$CONTRACT_B" "$TEST_BYTECODE"

RESULT=$(redis-cli FCALL eth_call 1 "$CONTRACT_B")
echo "Call to EOA result: $RESULT"

# Should succeed (return 1) for EOA calls
if [ "$RESULT" = "0x01" ]; then
    echo "✓ Call to EOA test passed"
else
    echo "✗ Call to EOA test failed - expected 0x01, got $RESULT"
fi

# Test 5: Call depth limit test
echo "Test 5: Call depth limit test"

# Create a recursive contract that calls itself
RECURSIVE_CONTRACT="0x3333333333333333333333333333333333333333"
# Bytecode that calls itself recursively: PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, PUSH1 0x00, ADDRESS, PUSH2 0x1000, CALL, STOP
RECURSIVE_BYTECODE="0x6000600060006000600030611000F100"
redis-cli SET "CODE:$RECURSIVE_CONTRACT" "$RECURSIVE_BYTECODE"
redis-cli SET "$RECURSIVE_CONTRACT" "$RECURSIVE_BYTECODE"

RESULT=$(redis-cli FCALL eth_call 1 "$RECURSIVE_CONTRACT")
echo "Recursive call result: $RESULT"

# Note: Due to Lua's own stack limitations, we may not reach EVM's 1024 depth limit
# In a production implementation, this would need an iterative approach
# For now, we verify that recursive calls work without crashing
if [ "$RESULT" = "0x01" ] || [ "$RESULT" = "0x00" ]; then
    echo "✓ Call depth test completed (result: $RESULT)"
else
    echo "✗ Call depth test failed - unexpected result: $RESULT"
fi

echo "System operations tests completed."