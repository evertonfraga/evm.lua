# Ethereum Foundation Tests Integration

This document describes how to integrate and run the official Ethereum Foundation test suite against EVM.lua.

## Overview

The Ethereum Foundation maintains a comprehensive test suite at https://github.com/ethereum/tests. These tests are the canonical reference for EVM compliance and are used by all major Ethereum clients.

## Test Structure

The tests are organized into several categories:

### GeneralStateTests (Most Relevant)
These are the primary tests for EVM execution:

- **stStackTests** - Stack operations (PUSH, POP, DUP, SWAP)
- **stArithmeticTest** - Arithmetic operations (ADD, SUB, MUL, DIV, MOD, EXP)
- **stMemoryTest** - Memory operations (MLOAD, MSTORE, MSIZE)
- **stSStoreTest** - Storage operations (SLOAD, SSTORE)
- **stLogTests** - Event logging (LOG0-LOG4)
- **stCallCodes** - Contract calls (CALL, CALLCODE, DELEGATECALL, STATICCALL)
- **stCreate2** - Contract creation (CREATE, CREATE2)
- **stReturnDataTest** - Return data operations
- **stRevertTest** - Revert operations
- **stSelfBalance** - SELFBALANCE opcode
- **stChainId** - CHAINID opcode
- **stCodeCopyTest** - Code copy operations
- **stJumpTest** - Jump operations (JUMP, JUMPI, JUMPDEST)

### Other Test Categories
- **BlockchainTests** - Full blockchain validation
- **TransactionTests** - Transaction validation
- **RLPTests** - RLP encoding/decoding
- **TrieTests** - Merkle Patricia Trie

## Test Format

Each test is a JSON file with the following structure:

```json
{
  "testName": {
    "env": {
      "currentCoinbase": "0x2adc25665018aa1fe0e6bc666dac8fc2697ff9ba",
      "currentDifficulty": "0x020000",
      "currentGasLimit": "0x0a00000000",
      "currentNumber": "0x01",
      "currentTimestamp": "0x03e8"
    },
    "pre": {
      "0xcontractAddress": {
        "balance": "0x0",
        "code": "0x600160010160005500",
        "nonce": "0x0",
        "storage": {}
      }
    },
    "transaction": {
      "data": ["0x"],
      "gasLimit": ["0x5f5e100"],
      "gasPrice": "0x0a",
      "nonce": "0x0",
      "to": "0xcontractAddress",
      "value": ["0x0"]
    },
    "post": {
      "Cancun": [
        {
          "hash": "0x...",
          "indexes": {"data": 0, "gas": 0, "value": 0},
          "logs": "0x...",
          "state": {
            "0xcontractAddress": {
              "balance": "0x0",
              "code": "0x600160010160005500",
              "nonce": "0x0",
              "storage": {
                "0x00": "0x02"
              }
            }
          }
        }
      ]
    }
  }
}
```

### Key Components

1. **env** - Block environment (coinbase, difficulty, gas limit, block number, timestamp)
2. **pre** - Initial state (accounts, balances, code, storage)
3. **transaction** - Transaction to execute (to, data, gas, value)
4. **post** - Expected state after execution (per fork)

## Integration Approach

### Phase 1: Test Infrastructure (Current)

1. ✅ Extract test files from archive
2. ✅ Create test adapter to parse JSON format
3. ✅ Map test format to EVM.lua execution model
4. 🔄 Implement state setup/verification

### Phase 2: Basic Test Execution

1. Run stack operation tests (stStackTests)
2. Run arithmetic tests (stArithmeticTest)
3. Run memory tests (stMemoryTest)
4. Compare results with expected post-state

### Phase 3: Comprehensive Testing

1. Run all implemented opcode tests
2. Identify failing tests
3. Fix implementation issues
4. Track compliance percentage

### Phase 4: Continuous Integration

1. Automate test runs in CI/CD
2. Generate compliance reports
3. Track regression

## Usage

### Extract Tests

```bash
cd tests
./eth-test-runner.sh extract
```

This extracts the test archive to `/tmp/GeneralStateTests/`.

### List Available Categories

```bash
./eth-test-runner.sh list
```

### Run Tests for a Category

Using the bash runner (basic):
```bash
./eth-test-runner.sh category stStackTests
```

Using the Python adapter (full):
```bash
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests -v
```

### Run Single Test File

```bash
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests/shallowStack.json -v
```

### Run All Implemented Tests

```bash
./eth-test-runner.sh implemented
```

## Test Adapter Architecture

The Python test adapter (`eth-test-adapter.py`) provides:

1. **JSON Parsing** - Loads and parses test files
2. **State Setup** - Configures Redis with pre-state
3. **Environment Setup** - Sets block context
4. **Transaction Execution** - Calls EVM via Redis
5. **State Verification** - Compares post-state with expectations
6. **Result Reporting** - Generates pass/fail reports

## Current Limitations

1. **Gas Metering** - Not fully implemented, so gas-related assertions may fail
2. **Nested Calls** - Call depth and context switching in progress
3. **State Root** - Not computing Merkle Patricia Trie roots
4. **Transaction Validation** - Not validating signatures/nonces
5. **Fork Selection** - Currently targeting Cancun fork

## Mapping to EVM.lua

### Pre-State Setup

```python
# Test format
"pre": {
  "0xaddress": {
    "code": "0x6001600101",
    "storage": {"0x00": "0x42"}
  }
}

# Maps to Redis
redis-cli SET "0xaddress" "6001600101"
redis-cli SET "0xaddress:storage:0x00" "0x42"
```

### Transaction Execution

```python
# Test format
"transaction": {
  "to": "0xaddress",
  "data": ["0x"],
  "gasLimit": ["0x5f5e100"]
}

# Maps to Redis call
redis-cli FCALL eth_call 1 "0xaddress"
```

### Post-State Verification

```python
# Test format
"post": {
  "Cancun": [{
    "state": {
      "0xaddress": {
        "storage": {"0x00": "0x02"}
      }
    }
  }]
}

# Verify with Redis
redis-cli GET "0xaddress:storage:0x00"
# Should return "0x02"
```

## Next Steps

1. **Enhance State Verification** - Implement full post-state checking
2. **Add Gas Tracking** - Compare gas usage with expectations
3. **Handle Multiple Variants** - Tests can have multiple data/gas/value combinations
4. **Fork Support** - Test against multiple forks (Frontier, Homestead, Byzantium, etc.)
5. **Failure Analysis** - Detailed reporting of why tests fail
6. **Performance** - Optimize for running thousands of tests

## Test Categories by Priority

### High Priority (Implemented Opcodes)
1. ✅ stStackTests - Stack operations
2. ✅ stArithmeticTest - Arithmetic
3. ✅ stMemoryTest - Memory operations
4. ✅ stSStoreTest - Storage
5. ✅ stLogTests - Event logging

### Medium Priority (Partially Implemented)
1. 🔄 stCallCodes - Contract calls
2. 🔄 stCreate2 - Contract creation
3. 🔄 stReturnDataTest - Return data
4. 🔄 stRevertTest - Revert operations

### Low Priority (Not Yet Implemented)
1. ❌ stEIP1559 - EIP-1559 gas
2. ❌ stEIP3860 - Initcode size limit
3. ❌ stEIP4844 - Blob transactions

## Resources

- [Ethereum Tests Repository](https://github.com/ethereum/tests)
- [Test Documentation](https://ethereum-tests.readthedocs.io/)
- [Test Format Specification](https://ethereum-tests.readthedocs.io/en/latest/test_types/state_tests.html)
- [EVM Opcodes Reference](https://evm.codes)
