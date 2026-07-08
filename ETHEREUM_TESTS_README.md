# Ethereum Foundation Tests Integration

## Overview

This project now includes full integration with the official Ethereum Foundation test suite, providing comprehensive validation of EVM.lua compliance against the same tests used by production Ethereum clients like geth, besu, and nethermind.

## What's Included

### Test Infrastructure
- **Bash Test Runner** (`tests/eth-test-runner.sh`) - Simple CLI for running tests
- **Python Test Adapter** (`tests/eth-test-adapter.py`) - Full-featured test execution and verification
- **Makefile Targets** - Convenient commands for common operations

### Documentation
- **[Quick Start Guide](./docs/ETH_TESTS_QUICKSTART.md)** - Get running in 5 minutes
- **[Integration Guide](./docs/ETHEREUM_TESTS_INTEGRATION.md)** - Comprehensive technical details
- **[Test Mapping](./docs/ETH_TESTS_MAPPING.md)** - Which tests cover which opcodes
- **[Checklist](./docs/ETH_TESTS_CHECKLIST.md)** - Track your testing progress
- **[Summary](./docs/ETH_TESTS_SUMMARY.md)** - Overview of the integration

### Test Suite
- **2000+ Test Files** - Comprehensive coverage of all EVM opcodes
- **50+ Categories** - Organized by opcode type and functionality
- **Multiple Forks** - Tests for Frontier through Cancun
- **10,000+ Test Cases** - Including variants and edge cases

## Quick Start

### 1. Extract Tests (First Time Only)
```bash
make test-eth-extract
```

### 2. Run Tests
```bash
# List available test categories
make test-eth-list

# Run tests for implemented opcodes
make test-eth

# Run specific category
python3 tests/eth-test-adapter.py /tmp/GeneralStateTests/stStackTests -v
```

## Test Categories

### ✅ High Priority (Fully Implemented)
- **stStackTests** - Stack operations (PUSH, POP, DUP, SWAP)
- **stArithmeticTest** - Arithmetic (ADD, SUB, MUL, DIV, MOD, EXP)
- **stMemoryTest** - Memory operations (MLOAD, MSTORE, MSIZE)
- **stSStoreTest** - Storage (SLOAD, SSTORE)
- **stLogTests** - Event logging (LOG0-LOG4)
- **stJumpTest** - Control flow (JUMP, JUMPI, JUMPDEST)
- **stKeccak256Test** - Hashing (KECCAK256)

### 🔄 Medium Priority (Partially Implemented)
- **stCallCodes** - Contract calls (CALL, CALLCODE, DELEGATECALL)
- **stReturnDataTest** - Return data operations
- **stRevertTest** - Revert operations

### ❌ Low Priority (Not Yet Implemented)
- **stCreate2** - Contract creation (CREATE, CREATE2)
- **stSuicide** - Self destruct (SELFDESTRUCT)

## Architecture

### Test Flow
```
1. Extract tests from archive
   ↓
2. Parse JSON test format
   ↓
3. Setup pre-state in Redis
   ↓
4. Execute transaction via EVM.lua
   ↓
5. Verify post-state matches expectations
   ↓
6. Report pass/fail results
```

### Test Format
Each test contains:
- **Pre-state**: Initial accounts, balances, code, storage
- **Transaction**: What to execute (to, data, gas, value)
- **Environment**: Block context (number, timestamp, coinbase)
- **Post-state**: Expected results after execution

### Integration with EVM.lua
```
Test JSON → Python Adapter → Redis Setup → EVM.lua Execution → Result Verification
```

## Usage Examples

### Run Single Test File
```bash
python3 tests/eth-test-adapter.py \
  /tmp/GeneralStateTests/stStackTests/shallowStack.json -v
```

### Run Test Category
```bash
python3 tests/eth-test-adapter.py \
  /tmp/GeneralStateTests/stStackTests -v
```

### Run Multiple Categories
```bash
for category in stStackTests stArithmeticTest stMemoryTest; do
  python3 tests/eth-test-adapter.py \
    /tmp/GeneralStateTests/$category -v
done
```

### Filter Tests by Name
```bash
# Run only PUSH tests
cd /tmp/GeneralStateTests/stStackTests
for f in *push*.json; do
  python3 ../../tests/eth-test-adapter.py "$f" -v
done
```

## Expected Results

### Current Implementation Status

Based on the 140/152 opcodes implemented:

| Category | Expected Pass Rate | Status |
|----------|-------------------|--------|
| Stack Operations | >90% | ✅ Should pass |
| Arithmetic | >90% | ✅ Should pass |
| Memory | >85% | ✅ Should pass |
| Storage | >85% | ✅ Should pass |
| Logging | >85% | ✅ Should pass |
| Control Flow | >85% | ✅ Should pass |
| Contract Calls | 30-60% | 🔄 In progress |
| Contract Creation | <20% | ❌ Not implemented |

### Known Limitations

1. **Gas Metering** - Not fully implemented, gas-related assertions may fail
2. **Nested Calls** - Call depth tracking in progress
3. **Contract Creation** - CREATE/CREATE2 not yet implemented
4. **Self Destruct** - SELFDESTRUCT not yet implemented

## Troubleshooting

### Redis Not Running
```bash
# Start Redis
redis-server

# Verify
redis-cli ping  # Should return PONG
```

### EVM Not Loaded
```bash
# Load EVM.lua
cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE
```

### Tests Not Found
```bash
# Extract tests
make test-eth-extract

# Verify
ls /tmp/GeneralStateTests/
```

### Python Errors
```bash
# Check Python version (need 3.6+)
python3 --version

# Install dependencies if needed
pip3 install redis
```

## Next Steps

### Phase 1: Validation (Current)
1. ✅ Extract and parse test files
2. ✅ Setup test infrastructure
3. 🔄 Run tests for implemented opcodes
4. 🔄 Document pass rates

### Phase 2: Improvement
1. Fix failing tests in implemented opcodes
2. Enhance post-state verification
3. Add gas tracking
4. Improve error reporting

### Phase 3: Completion
1. Implement missing opcodes (CREATE, SELFDESTRUCT)
2. Complete nested call support
3. Add full gas metering
4. Achieve >95% compliance

### Phase 4: Automation
1. Integrate with CI/CD
2. Generate compliance reports
3. Track regression
4. Publish metrics

## Contributing

To improve test compliance:

1. **Run tests** and identify failures
2. **Debug** the specific opcode or behavior
3. **Fix** the issue in `evm.lua`
4. **Verify** with both custom and Ethereum tests
5. **Document** the fix and any limitations

## Resources

### Documentation
- [Quick Start Guide](./docs/ETH_TESTS_QUICKSTART.md) - Get started in 5 minutes
- [Integration Guide](./docs/ETHEREUM_TESTS_INTEGRATION.md) - Technical details
- [Test Mapping](./docs/ETH_TESTS_MAPPING.md) - Opcode to test mapping
- [Checklist](./docs/ETH_TESTS_CHECKLIST.md) - Progress tracking

### External Resources
- [Ethereum Tests Repository](https://github.com/ethereum/tests)
- [Test Documentation](https://ethereum-tests.readthedocs.io/)
- [EVM Opcodes Reference](https://evm.codes)
- [Test Format Specification](https://ethereum-tests.readthedocs.io/en/latest/test_types/state_tests.html)

### Tools
- `tests/eth-test-runner.sh` - Bash test runner
- `tests/eth-test-adapter.py` - Python test adapter
- `Makefile` - Build targets for testing

## Compliance Tracking

Track your progress:

```
Current Status (Example):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stack Operations:     ████████████░░  90% (36/40)
Arithmetic:           ██████████████ 100% (25/25)
Memory:               ███████████░░░  85% (17/20)
Storage:              ███████████░░░  85% (17/20)
Control Flow:         ██████████░░░░  80% (16/20)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Overall Compliance:   ███████████░░░  88% (111/125)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Success Metrics

### Minimum Viable
- ✅ Test infrastructure working
- ✅ Can run individual tests
- ✅ Can run test categories
- 🔄 >70% overall pass rate

### Production Ready
- 🔄 >85% overall pass rate
- 🔄 >95% for implemented opcodes
- 🔄 Zero regressions
- 🔄 Automated testing

### Full Compliance
- ❌ >95% overall pass rate
- ❌ All opcodes implemented
- ❌ Gas metering accurate
- ❌ Multi-fork support

## License

The Ethereum Foundation tests are licensed under MIT. See `ethereum-tests/LICENSE` for details.

## Acknowledgments

- Ethereum Foundation for maintaining the test suite
- All Ethereum client teams for contributing tests
- The EVM.lua project contributors

---

**Ready to start testing?** Run `make test-eth-extract` and follow the [Quick Start Guide](./docs/ETH_TESTS_QUICKSTART.md)!
