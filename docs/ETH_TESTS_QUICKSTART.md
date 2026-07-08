# Ethereum Tests Quick Start Guide

Get started with running official Ethereum Foundation tests against EVM.lua in 5 minutes.

## Prerequisites

- Redis server running
- Python 3.6+
- Bash shell
- EVM.lua loaded into Redis

## Quick Start

### 1. Extract Test Files

```bash
make test-eth-extract
```

This extracts ~2000+ test files from the archive to `/tmp/GeneralStateTests/`.

### 2. List Available Test Categories

```bash
make test-eth-list
```

You'll see categories like:
- stStackTests (stack operations)
- stArithmeticTest (arithmetic)
- stMemoryTest (memory operations)
- stSStoreTest (storage)
- And many more...

### 3. Run a Single Test File

```bash
cd tests
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests/shallowStack.json -v
```

### 4. Run All Tests in a Category

```bash
cd tests
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests -v
```

### 5. Run Tests for Implemented Opcodes

```bash
make test-eth
```

This runs tests for all opcodes currently implemented in EVM.lua.

## Understanding Test Output

### Successful Test
```
✓ Test passed: shallowStack
  Expected storage: 0x02
  Got storage: 0x02
```

### Failed Test
```
✗ Test failed: complexStack
  Expected storage: 0x42
  Got storage: 0x00
```

## Test Categories Mapped to Opcodes

| Category | Opcodes Tested | Status |
|----------|---------------|--------|
| stStackTests | PUSH, POP, DUP, SWAP | ✅ Implemented |
| stArithmeticTest | ADD, SUB, MUL, DIV, MOD, EXP | ✅ Implemented |
| stMemoryTest | MLOAD, MSTORE, MSIZE | ✅ Implemented |
| stSStoreTest | SLOAD, SSTORE | ✅ Implemented |
| stLogTests | LOG0-LOG4 | ✅ Implemented |
| stCallCodes | CALL, CALLCODE, DELEGATECALL | 🔄 In Progress |
| stCreate2 | CREATE, CREATE2 | 🔄 In Progress |
| stReturnDataTest | RETURNDATASIZE, RETURNDATACOPY | ❌ Not Yet |

## Common Issues

### Redis Not Running
```
Error: Could not connect to Redis
```
**Solution:** Start Redis with `redis-server`

### Tests Not Extracted
```
Error: /tmp/GeneralStateTests not found
```
**Solution:** Run `make test-eth-extract` first

### EVM Function Not Loaded
```
Error: Function eth_call not found
```
**Solution:** Load EVM with `cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE`

## Advanced Usage

### Run Specific Fork Tests

```bash
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests --fork Cancun -v
```

### Filter Tests by Name

```bash
# Run only tests with "push" in the name
cd /tmp/GeneralStateTests/stStackTests
for f in *push*.json; do
    python3 ../../tests/eth-test-adapter.py "$f" -v
done
```

### Generate Compliance Report

```bash
cd tests
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests > stack-report.txt
```

## Next Steps

1. Review the full integration guide: `docs/ETHEREUM_TESTS_INTEGRATION.md`
2. Check test results and identify failures
3. Fix implementation issues in `evm.lua`
4. Re-run tests to verify fixes
5. Track compliance percentage over time

## Test File Structure

Each test file contains:
- **Pre-state**: Initial account balances, code, storage
- **Transaction**: What to execute (to, data, gas, value)
- **Environment**: Block context (number, timestamp, coinbase)
- **Post-state**: Expected results after execution

Example test structure:
```json
{
  "testName": {
    "pre": { /* initial state */ },
    "transaction": { /* what to execute */ },
    "env": { /* block context */ },
    "post": { /* expected results */ }
  }
}
```

## Debugging Failed Tests

### 1. Run with Verbose Output
```bash
python3 eth-test-adapter.py test.json -v
```

### 2. Check Redis State
```bash
redis-cli GET "0xcontractaddress"
redis-cli GET "0xcontractaddress:storage:0x00"
```

### 3. Manually Execute Bytecode
```bash
redis-cli SET "0xtest" "600160010160005500"
redis-cli FCALL eth_call 1 "0xtest"
```

### 4. Compare with Expected
Look at the test JSON's `post` section to see what's expected.

## Contributing

Found a bug? Fixed a failing test? 

1. Document the issue
2. Create a fix in `evm.lua`
3. Verify with `make test-all`
4. Run Ethereum tests: `make test-eth`
5. Submit your changes

## Resources

- [Full Integration Guide](./ETHEREUM_TESTS_INTEGRATION.md)
- [Ethereum Tests Repo](https://github.com/ethereum/tests)
- [EVM Opcodes Reference](https://evm.codes)
- [Test Format Docs](https://ethereum-tests.readthedocs.io/)
