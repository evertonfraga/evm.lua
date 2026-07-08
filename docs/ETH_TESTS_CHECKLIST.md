# Ethereum Tests Integration Checklist

Use this checklist to track your progress integrating and running Ethereum Foundation tests.

## Setup Phase

- [ ] **Extract test files**
  ```bash
  make test-eth-extract
  ```
  Verify: `/tmp/GeneralStateTests/` directory exists with 50+ subdirectories

- [ ] **Verify Redis is running**
  ```bash
  redis-cli ping
  ```
  Expected output: `PONG`

- [ ] **Load EVM.lua into Redis**
  ```bash
  cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE
  ```
  Expected output: Function library loaded successfully

- [ ] **List available test categories**
  ```bash
  make test-eth-list
  ```
  Expected: List of 50+ test categories

## Basic Testing Phase

- [ ] **Run a single test file**
  ```bash
  python3 tests/eth-test-adapter.py /tmp/GeneralStateTests/stStackTests/shallowStack.json -v
  ```
  Expected: Test execution completes without errors

- [ ] **Run stack tests category**
  ```bash
  python3 tests/eth-test-adapter.py /tmp/GeneralStateTests/stStackTests -v
  ```
  Expected: Multiple tests run, some pass/fail reported

- [ ] **Run arithmetic tests**
  ```bash
  python3 tests/eth-test-adapter.py /tmp/GeneralStateTests/stArithmeticTest -v
  ```
  Expected: Arithmetic operations tested

## Comprehensive Testing Phase

### Priority 1: Fully Implemented Opcodes

- [ ] **Stack Operations** (stStackTests)
  - Expected: High pass rate (>90%)
  - Opcodes: PUSH, POP, DUP, SWAP

- [ ] **Arithmetic** (stArithmeticTest)
  - Expected: High pass rate (>90%)
  - Opcodes: ADD, SUB, MUL, DIV, MOD, EXP

- [ ] **Bitwise Operations** (stBitwiseLogicOperation)
  - Expected: High pass rate (>90%)
  - Opcodes: AND, OR, XOR, NOT, SHL, SHR, SAR

- [ ] **Memory Operations** (stMemoryTest)
  - Expected: High pass rate (>85%)
  - Opcodes: MLOAD, MSTORE, MSTORE8, MSIZE

- [ ] **Storage Operations** (stSStoreTest)
  - Expected: High pass rate (>85%)
  - Opcodes: SLOAD, SSTORE

- [ ] **Control Flow** (stJumpTest)
  - Expected: High pass rate (>85%)
  - Opcodes: JUMP, JUMPI, JUMPDEST

- [ ] **Environment Info** (stEnvironmentalInfo)
  - Expected: Moderate pass rate (>70%)
  - Opcodes: ADDRESS, CALLER, CALLVALUE, etc.

- [ ] **Block Info** (stBlockHashTest)
  - Expected: High pass rate (>85%)
  - Opcodes: BLOCKHASH, COINBASE, TIMESTAMP, NUMBER

- [ ] **Hashing** (stKeccak256Test)
  - Expected: High pass rate (>90%)
  - Opcodes: KECCAK256

- [ ] **Logging** (stLogTests)
  - Expected: High pass rate (>85%)
  - Opcodes: LOG0, LOG1, LOG2, LOG3, LOG4

### Priority 2: Partially Implemented

- [ ] **Contract Calls** (stCallCodes)
  - Expected: Low-moderate pass rate (30-60%)
  - Opcodes: CALL, CALLCODE, DELEGATECALL, STATICCALL
  - Known issues: Nested call context in progress

- [ ] **Return Data** (stReturnDataTest)
  - Expected: Moderate pass rate (50-70%)
  - Opcodes: RETURNDATASIZE, RETURNDATACOPY, RETURN

- [ ] **Revert** (stRevertTest)
  - Expected: Moderate pass rate (60-80%)
  - Opcodes: REVERT

### Priority 3: Not Yet Implemented

- [ ] **Contract Creation** (stCreate2, stCreateTest)
  - Expected: Low pass rate (<20%)
  - Opcodes: CREATE, CREATE2
  - Status: Not implemented

- [ ] **Self Destruct** (stSuicide)
  - Expected: Fail
  - Opcodes: SELFDESTRUCT
  - Status: Not implemented

## Analysis Phase

- [ ] **Document pass rates**
  Create a spreadsheet or document tracking:
  - Test category
  - Total tests
  - Passed tests
  - Failed tests
  - Pass rate %

- [ ] **Identify failure patterns**
  - Are failures in specific opcodes?
  - Are failures related to gas metering?
  - Are failures in edge cases?

- [ ] **Prioritize fixes**
  - Fix high-impact failures first
  - Focus on fully implemented opcodes
  - Document known limitations

## Fix and Iterate Phase

- [ ] **Fix identified issues**
  For each failing test:
  1. Understand what the test expects
  2. Debug EVM.lua implementation
  3. Fix the issue
  4. Re-run the test
  5. Verify fix doesn't break other tests

- [ ] **Re-run full test suite**
  ```bash
  make test-all
  make test-eth
  ```

- [ ] **Track compliance improvement**
  - Document before/after pass rates
  - Celebrate improvements!

## Documentation Phase

- [ ] **Document test results**
  - Create compliance report
  - List known limitations
  - Document workarounds

- [ ] **Update README**
  - Add compliance percentage
  - Link to test results
  - Update opcode implementation status

- [ ] **Create issue tracker**
  - File issues for failing tests
  - Tag by priority
  - Link to specific test files

## Automation Phase

- [ ] **Create test automation script**
  - Run all tests automatically
  - Generate reports
  - Compare with previous runs

- [ ] **Set up CI/CD**
  - Run tests on each commit
  - Fail build on regression
  - Generate compliance reports

- [ ] **Create compliance dashboard**
  - Visualize pass rates
  - Track trends over time
  - Highlight regressions

## Maintenance Phase

- [ ] **Regular test runs**
  - Run tests weekly
  - Track compliance trends
  - Identify regressions early

- [ ] **Update tests**
  - Pull latest tests from Ethereum repo
  - Test against new forks
  - Update documentation

- [ ] **Share results**
  - Publish compliance reports
  - Share with community
  - Get feedback

## Success Criteria

### Minimum Viable Compliance
- [ ] Stack operations: >90% pass rate
- [ ] Arithmetic: >90% pass rate
- [ ] Memory: >85% pass rate
- [ ] Storage: >85% pass rate
- [ ] Overall: >70% pass rate

### Production Ready Compliance
- [ ] All implemented opcodes: >95% pass rate
- [ ] Contract calls: >80% pass rate
- [ ] Overall: >85% pass rate
- [ ] Zero regressions in existing tests

### Full Compliance
- [ ] All test categories: >95% pass rate
- [ ] All opcodes implemented
- [ ] Gas metering accurate
- [ ] Multiple fork support
- [ ] Overall: >95% pass rate

## Common Issues and Solutions

### Issue: Tests fail with "Function not found"
**Solution**: Load EVM.lua into Redis
```bash
cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE
```

### Issue: Tests fail with "Connection refused"
**Solution**: Start Redis server
```bash
redis-server
```

### Issue: Tests not found
**Solution**: Extract test files
```bash
make test-eth-extract
```

### Issue: Python script fails
**Solution**: Check Python version (need 3.6+)
```bash
python3 --version
```

### Issue: Gas-related failures
**Solution**: Known limitation - gas metering not fully implemented
- Document as known issue
- Focus on non-gas assertions first

### Issue: Nested call failures
**Solution**: Known limitation - call depth tracking in progress
- Document as known issue
- Test will improve as feature is completed

## Quick Reference Commands

```bash
# Extract tests
make test-eth-extract

# List categories
make test-eth-list

# Run single test
python3 tests/eth-test-adapter.py /tmp/GeneralStateTests/stStackTests/test.json -v

# Run category
python3 tests/eth-test-adapter.py /tmp/GeneralStateTests/stStackTests -v

# Run all implemented
make test-eth

# Check Redis
redis-cli ping

# Load EVM
cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE

# Run custom tests
make test-all
```

## Progress Tracking Template

```
Date: ___________
Tester: ___________

Test Results:
- stStackTests:        ___/___  (___%)
- stArithmeticTest:    ___/___  (___%)
- stMemoryTest:        ___/___  (___%)
- stSStoreTest:        ___/___  (___%)
- stLogTests:          ___/___  (___%)
- stCallCodes:         ___/___  (___%)
- Other:               ___/___  (___%)

Overall:               ___/___  (___%)

Notes:
_________________________________
_________________________________
_________________________________

Next Steps:
1. _________________________________
2. _________________________________
3. _________________________________
```

## Resources

- [Quick Start Guide](./ETH_TESTS_QUICKSTART.md)
- [Integration Guide](./ETHEREUM_TESTS_INTEGRATION.md)
- [Test Mapping](./ETH_TESTS_MAPPING.md)
- [Summary](./ETH_TESTS_SUMMARY.md)
