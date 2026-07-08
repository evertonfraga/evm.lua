# Ethereum Tests Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Ethereum Foundation Tests                     │
│                  (ethereum-tests repository)                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Extracted to
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              /tmp/GeneralStateTests/                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ stStackTests │  │stArithmetic  │  │ stMemoryTest │  ...      │
│  │  (40 files)  │  │  (25 files)  │  │  (20 files)  │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Read by
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Python Test Adapter                                │
│              (eth-test-adapter.py)                              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────── ┐   │
│  │ 1. Parse JSON test format                                │   │
│  │ 2. Extract pre-state, transaction, environment           │   │
│  │ 3. Setup Redis with initial state                        │   │
│  │ 4. Execute transaction via EVM.lua                       │   │
│  │ 5. Verify post-state matches expectations                │   │
│  │ 6. Report results                                        │   │
│  └─────────────────────────────────────────────────────────┘    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Interacts with
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Redis Database                           │
│                                                                 │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │  Contract Code   │  │  Account State   │  │  Block Info   │  │
│  │                  │  │                  │  │               │  │
│  │ 0xaddr → bytecode│  │ 0xaddr:balance   │  │ block:number  │  │
│  │                  │  │ 0xaddr:nonce     │  │ block:time    │  │
│  │                  │  │ 0xaddr:storage:* │  │ block:coinbase│  │
│  └──────────────────┘  └──────────────────┘  └───────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              EVM.lua (Loaded as Function)               │    │
│  │                                                         │    │
│  │  • Bytecode interpreter                                 │    │
│  │  • Opcode implementations (140/152)                     │    │
│  │  • Stack, memory, storage management                    │    │
│  │  • Execution context                                    │    │
│  └─────────────────────────────────────────────────────────┘    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ Returns results to
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Test Results                               │
│                                                                 │
│  ✓ Test passed: shallowStack                                    │
│  ✗ Test failed: complexStack                                    │
│  ✓ Test passed: stackOverflow                                   │
│                                                                 │
│  Summary: 38/40 passed (95%)                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Test File Structure

```json
{
  "testName": {
    "env": {
      "currentCoinbase": "0x2adc...",
      "currentNumber": "0x01",
      "currentTimestamp": "0x03e8"
    },
    "pre": {
      "0xcontractAddr": {
        "balance": "0x0",
        "code": "0x600160010160005500",
        "nonce": "0x0",
        "storage": {}
      }
    },
    "transaction": {
      "to": "0xcontractAddr",
      "data": ["0x"],
      "gasLimit": ["0x5f5e100"],
      "value": ["0x0"]
    },
    "post": {
      "Cancun": [{
        "state": {
          "0xcontractAddr": {
            "storage": {"0x00": "0x02"}
          }
        }
      }]
    }
  }
}
```

### 2. Pre-State Setup

```
Test JSON                    Redis Commands
─────────────────────────────────────────────────────────
"pre": {                     
  "0xaddr": {                
    "code": "0x6001..."   →  SET 0xaddr "6001..."
    "balance": "0x100"    →  SET 0xaddr:balance "0x100"
    "nonce": "0x0"        →  SET 0xaddr:nonce "0x0"
    "storage": {
      "0x00": "0x42"      →  SET 0xaddr:storage:0x00 "0x42"
    }
  }
}
```

### 3. Environment Setup

```
Test JSON                    Redis Commands
─────────────────────────────────────────────────────────
"env": {
  "currentNumber": "0x01" →  SET block:number "0x01"
  "currentTimestamp": ... →  SET block:timestamp "0x03e8"
  "currentCoinbase": ...  →  SET block:coinbase "0x2adc..."
  "currentGasLimit": ...  →  SET block:gaslimit "0x0a00000000"
}
```

### 4. Transaction Execution

```
Test JSON                    Redis Command
─────────────────────────────────────────────────────────
"transaction": {
  "to": "0xaddr",         →  FCALL eth_call 1 "0xaddr"
  "data": ["0x"],
  "gasLimit": ["0x5f..."]
}
```

### 5. Post-State Verification

```
Test JSON                    Redis Query
─────────────────────────────────────────────────────────
"post": {
  "Cancun": [{
    "state": {
      "0xaddr": {
        "storage": {
          "0x00": "0x02"  →  GET 0xaddr:storage:0x00
        }                     (verify equals "0x02")
      }
    }
  }]
}
```

## Component Interaction

### Test Adapter Components

```
┌─────────────────────────────────────────────────────────┐
│              EVMTestAdapter Class                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  load_test_file(path)                                   │
│    └─> Parse JSON test file                             │
│                                                           │
│  setup_prestate(pre)                                    │
│    └─> Configure accounts in Redis                      │
│        ├─> Set contract code                            │
│        ├─> Set balances                                 │
│        ├─> Set nonces                                   │
│        └─> Set storage values                           │
│                                                           │
│  setup_environment(env)                                 │
│    └─> Configure block context                          │
│        ├─> Set block number                             │
│        ├─> Set timestamp                                │
│        ├─> Set coinbase                                 │
│        └─> Set gas limit                                │
│                                                           │
│  execute_transaction(tx)                                │
│    └─> Call EVM via Redis                               │
│        └─> FCALL eth_call 1 <address>                   │
│                                                           │
│  verify_poststate(post)                                 │
│    └─> Check results match expectations                 │
│        ├─> Verify storage values                        │
│        ├─> Verify balances                              │
│        ├─> Verify nonces                                │
│        └─> Verify logs                                  │
│                                                           │
│  run_test(path)                                         │
│    └─> Orchestrate full test execution                  │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### EVM.lua Execution Flow

```
┌─────────────────────────────────────────────────────────┐
│              eth_call Function                           │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  1. Load contract bytecode from Redis                   │
│     GET <address>                                        │
│                                                           │
│  2. Initialize EVM state                                 │
│     ├─> Stack: []                                        │
│     ├─> Memory: []                                       │
│     ├─> PC: 0                                            │
│     └─> Storage: loaded from Redis                      │
│                                                           │
│  3. Execute bytecode                                     │
│     ┌─────────────────────────────────────┐            │
│     │ while PC < bytecode length:          │            │
│     │   opcode = bytecode[PC]              │            │
│     │   execute_opcode(opcode)             │            │
│     │   PC += 1 + operand_size             │            │
│     └─────────────────────────────────────┘            │
│                                                           │
│  4. Handle opcodes                                       │
│     ├─> Stack ops (PUSH, POP, DUP, SWAP)                │
│     ├─> Arithmetic (ADD, SUB, MUL, DIV)                 │
│     ├─> Memory (MLOAD, MSTORE)                          │
│     ├─> Storage (SLOAD, SSTORE)                         │
│     ├─> Control (JUMP, JUMPI, STOP)                     │
│     └─> System (CALL, RETURN, REVERT)                   │
│                                                           │
│  5. Persist state changes                                │
│     ├─> Write storage to Redis                          │
│     ├─> Update balances                                 │
│     └─> Record logs                                     │
│                                                           │
│  6. Return result                                        │
│     └─> Top of stack or return data                     │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Test Execution Sequence

```
User Command
    │
    ▼
┌─────────────────────────────────────────┐
│ python3 eth-test-adapter.py <path>      │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Load test JSON file                      │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ For each test case in file:             │
│                                          │
│  1. Clear Redis state                   │
│     └─> FLUSHDB                          │
│                                          │
│  2. Setup pre-state                     │
│     └─> SET contract code               │
│     └─> SET account balances            │
│     └─> SET storage values              │
│                                          │
│  3. Setup environment                   │
│     └─> SET block context               │
│                                          │
│  4. Execute transaction                 │
│     └─> FCALL eth_call                  │
│                                          │
│  5. Verify post-state                   │
│     └─> GET storage values              │
│     └─> Compare with expected           │
│                                          │
│  6. Record result                       │
│     └─> Pass or Fail                    │
│                                          │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│ Generate report                          │
│  • Total tests                           │
│  • Passed tests                          │
│  • Failed tests                          │
│  • Pass rate                             │
└─────────────────────────────────────────┘
```

## File Organization

```
evm-redis/
├── ethereum-tests/                    # Official test suite
│   ├── fixtures_general_state_tests.tgz
│   └── ...
│
├── tests/
│   ├── eth-test-runner.sh            # Bash test runner
│   ├── eth-test-adapter.py           # Python test adapter
│   ├── lib.sh                        # Shared utilities
│   └── test-*.sh                     # Custom tests
│
├── docs/
│   ├── ETH_TESTS_QUICKSTART.md       # Quick start guide
│   ├── ETHEREUM_TESTS_INTEGRATION.md # Full integration guide
│   ├── ETH_TESTS_MAPPING.md          # Test to opcode mapping
│   ├── ETH_TESTS_CHECKLIST.md        # Progress checklist
│   ├── ETH_TESTS_SUMMARY.md          # Summary
│   └── ETH_TESTS_ARCHITECTURE.md     # This file
│
├── evm.lua                            # EVM implementation
├── Makefile                           # Build targets
└── ETHEREUM_TESTS_README.md          # Main test documentation
```

## Redis Key Schema

```
Contract Code:
  <address>                    → bytecode (hex string)

Account State:
  <address>:balance            → balance (hex string)
  <address>:nonce              → nonce (hex string)
  <address>:storage:<key>      → value (hex string)

Block Context:
  block:number                 → block number (hex)
  block:timestamp              → timestamp (hex)
  block:coinbase               → coinbase address (hex)
  block:gaslimit               → gas limit (hex)
  block:difficulty             → difficulty (hex)
  block:basefee                → base fee (hex)

Transaction Context:
  tx:to                        → recipient address
  tx:data                      → call data
  tx:gas                       → gas limit
  tx:value                     → value transferred
  tx:caller                    → caller address
```

## Error Handling

```
┌─────────────────────────────────────────┐
│ Test Execution                           │
└────────────────┬────────────────────────┘
                 │
                 ▼
         ┌───────────────┐
         │ Try Execute   │
         └───────┬───────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
   ┌─────────┐      ┌──────────┐
   │ Success │      │  Error   │
   └────┬────┘      └─────┬────┘
        │                 │
        ▼                 ▼
   ┌─────────┐      ┌──────────┐
   │ Verify  │      │  Catch   │
   │  Post   │      │  & Log   │
   └────┬────┘      └─────┬────┘
        │                 │
        ▼                 ▼
   ┌─────────┐      ┌──────────┐
   │  Pass   │      │   Fail   │
   └─────────┘      └──────────┘
```

## Performance Considerations

### Test Execution Speed

```
Single Test:     ~10-50ms
Test File:       ~1-5 seconds (10-100 tests)
Test Category:   ~30-300 seconds (100-1000 tests)
Full Suite:      ~30-60 minutes (10,000+ tests)
```

### Optimization Strategies

1. **Parallel Execution** - Run multiple test files concurrently
2. **Redis Pipelining** - Batch Redis commands
3. **Selective Testing** - Run only relevant tests
4. **Caching** - Cache parsed test files
5. **Incremental Testing** - Only run changed tests

## Future Enhancements

### Phase 1: Current
- ✅ Basic test execution
- ✅ Pre-state setup
- ✅ Transaction execution
- 🔄 Post-state verification

### Phase 2: Enhanced Verification
- Full post-state checking
- Gas usage verification
- Log verification
- Multiple test variants

### Phase 3: Advanced Features
- Parallel test execution
- HTML report generation
- Compliance dashboard
- Regression tracking

### Phase 4: CI/CD Integration
- Automated test runs
- GitHub Actions integration
- Compliance badges
- Performance benchmarks
