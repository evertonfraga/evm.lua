# Ethereum Test Categories to Opcode Mapping

This document maps Ethereum Foundation test categories to the specific opcodes they test, helping you identify which tests to run for your implementation.

## Test Category Reference

### Stack Operations

#### stStackTests
**Opcodes**: `0x50-0x5F`, `0x60-0x7F`, `0x80-0x8F`, `0x90-0x9F`
- `POP` (0x50) - Remove item from stack
- `PUSH0` (0x5F) - Push 0 onto stack
- `PUSH1-PUSH32` (0x60-0x7F) - Push 1-32 bytes onto stack
- `DUP1-DUP16` (0x80-0x8F) - Duplicate stack items
- `SWAP1-SWAP16` (0x90-0x9F) - Swap stack items

**Status**: ✅ Fully implemented in EVM.lua

---

### Arithmetic Operations

#### stArithmeticTest
**Opcodes**: `0x01-0x0B`
- `ADD` (0x01) - Addition
- `MUL` (0x02) - Multiplication
- `SUB` (0x03) - Subtraction
- `DIV` (0x04) - Integer division
- `SDIV` (0x05) - Signed integer division
- `MOD` (0x06) - Modulo
- `SMOD` (0x07) - Signed modulo
- `ADDMOD` (0x08) - Modular addition
- `MULMOD` (0x09) - Modular multiplication
- `EXP` (0x0A) - Exponentiation
- `SIGNEXTEND` (0x0B) - Sign extension

**Status**: ✅ Fully implemented in EVM.lua

---

### Comparison & Bitwise Operations

#### stBitwiseLogicOperation
**Opcodes**: `0x10-0x1D`
- `LT` (0x10) - Less than
- `GT` (0x11) - Greater than
- `SLT` (0x12) - Signed less than
- `SGT` (0x13) - Signed greater than
- `EQ` (0x14) - Equality
- `ISZERO` (0x15) - Is zero
- `AND` (0x16) - Bitwise AND
- `OR` (0x17) - Bitwise OR
- `XOR` (0x18) - Bitwise XOR
- `NOT` (0x19) - Bitwise NOT
- `BYTE` (0x1A) - Retrieve single byte
- `SHL` (0x1B) - Shift left
- `SHR` (0x1C) - Logical shift right
- `SAR` (0x1D) - Arithmetic shift right

**Status**: ✅ Fully implemented in EVM.lua

---

### Memory Operations

#### stMemoryTest
**Opcodes**: `0x51-0x53`, `0x59`
- `MLOAD` (0x51) - Load word from memory
- `MSTORE` (0x52) - Store word to memory
- `MSTORE8` (0x53) - Store byte to memory
- `MSIZE` (0x59) - Get memory size

**Status**: ✅ Fully implemented in EVM.lua

#### stMemoryStressTest
**Purpose**: Tests memory expansion and gas costs
**Opcodes**: Same as stMemoryTest but with edge cases

**Status**: ✅ Implemented, may have gas metering gaps

---

### Storage Operations

#### stSStoreTest
**Opcodes**: `0x54-0x55`
- `SLOAD` (0x54) - Load from storage
- `SSTORE` (0x55) - Store to storage

**Status**: ✅ Fully implemented in EVM.lua

#### stStorageTest
**Purpose**: Complex storage patterns and gas costs
**Opcodes**: `SLOAD`, `SSTORE` with various patterns

**Status**: ✅ Implemented, may have gas metering gaps

---

### Control Flow

#### stJumpTest
**Opcodes**: `0x56-0x58`, `0x5B`
- `JUMP` (0x56) - Unconditional jump
- `JUMPI` (0x57) - Conditional jump
- `PC` (0x58) - Program counter
- `JUMPDEST` (0x5B) - Jump destination marker

**Status**: ✅ Fully implemented in EVM.lua

#### stStopTest
**Opcodes**: `0x00`
- `STOP` (0x00) - Halt execution

**Status**: ✅ Fully implemented in EVM.lua

---

### Environment Information

#### stEnvironmentalInfo
**Opcodes**: `0x30-0x3F`
- `ADDRESS` (0x30) - Get executing contract address
- `BALANCE` (0x31) - Get account balance
- `ORIGIN` (0x32) - Get transaction origin
- `CALLER` (0x33) - Get caller address
- `CALLVALUE` (0x34) - Get call value
- `CALLDATALOAD` (0x35) - Load call data
- `CALLDATASIZE` (0x36) - Get call data size
- `CALLDATACOPY` (0x37) - Copy call data
- `CODESIZE` (0x38) - Get code size
- `CODECOPY` (0x39) - Copy code
- `GASPRICE` (0x3A) - Get gas price
- `EXTCODESIZE` (0x3B) - Get external code size
- `EXTCODECOPY` (0x3C) - Copy external code
- `RETURNDATASIZE` (0x3D) - Get return data size
- `RETURNDATACOPY` (0x3E) - Copy return data
- `EXTCODEHASH` (0x3F) - Get external code hash

**Status**: ✅ Mostly implemented in EVM.lua

---

### Block Information

#### stBlockHashTest
**Opcodes**: `0x40-0x48`
- `BLOCKHASH` (0x40) - Get block hash
- `COINBASE` (0x41) - Get block coinbase
- `TIMESTAMP` (0x42) - Get block timestamp
- `NUMBER` (0x43) - Get block number
- `DIFFICULTY` (0x44) - Get block difficulty
- `GASLIMIT` (0x45) - Get block gas limit
- `CHAINID` (0x46) - Get chain ID
- `SELFBALANCE` (0x47) - Get own balance
- `BASEFEE` (0x48) - Get base fee

**Status**: ✅ Fully implemented in EVM.lua

---

### Hashing

#### stKeccak256Test
**Opcodes**: `0x20`
- `KECCAK256` (0x20) - Compute Keccak-256 hash

**Status**: ✅ Fully implemented in EVM.lua

---

### Logging

#### stLogTests
**Opcodes**: `0xA0-0xA4`
- `LOG0` (0xA0) - Log with 0 topics
- `LOG1` (0xA1) - Log with 1 topic
- `LOG2` (0xA2) - Log with 2 topics
- `LOG3` (0xA3) - Log with 3 topics
- `LOG4` (0xA4) - Log with 4 topics

**Status**: ✅ Fully implemented in EVM.lua

---

### System Operations

#### stCallCodes
**Opcodes**: `0xF1-0xF2`, `0xF4`, `0xFA`
- `CALL` (0xF1) - Call another contract
- `CALLCODE` (0xF2) - Call with alternative code
- `DELEGATECALL` (0xF4) - Delegate call
- `STATICCALL` (0xFA) - Static call

**Status**: 🔄 In progress in EVM.lua

#### stCallCreateCallCodeTest
**Purpose**: Tests nested calls and contract creation
**Opcodes**: `CALL`, `CALLCODE`, `CREATE`

**Status**: 🔄 In progress in EVM.lua

#### stDelegatecallTestHomestead
**Purpose**: Tests DELEGATECALL behavior
**Opcodes**: `DELEGATECALL` (0xF4)

**Status**: 🔄 In progress in EVM.lua

#### stStaticCall
**Purpose**: Tests STATICCALL behavior
**Opcodes**: `STATICCALL` (0xFA)

**Status**: 🔄 In progress in EVM.lua

---

### Contract Creation

#### stCreate2
**Opcodes**: `0xF0`, `0xF5`
- `CREATE` (0xF0) - Create new contract
- `CREATE2` (0xF5) - Create contract with deterministic address

**Status**: ❌ Not yet implemented in EVM.lua

#### stCreateTest
**Purpose**: Tests CREATE opcode
**Opcodes**: `CREATE` (0xF0)

**Status**: ❌ Not yet implemented in EVM.lua

---

### Return Operations

#### stReturnDataTest
**Opcodes**: `0x3D-0x3E`, `0xF3`, `0xFD`
- `RETURNDATASIZE` (0x3D) - Get return data size
- `RETURNDATACOPY` (0x3E) - Copy return data
- `RETURN` (0xF3) - Return from call
- `REVERT` (0xFD) - Revert state changes

**Status**: ✅ RETURN/REVERT implemented, return data in progress

#### stRevertTest
**Purpose**: Tests REVERT behavior
**Opcodes**: `REVERT` (0xFD)

**Status**: ✅ Implemented in EVM.lua

---

### Self-Destruct

#### stSelfBalance
**Opcodes**: `0x47`
- `SELFBALANCE` (0x47) - Get own balance

**Status**: ✅ Implemented in EVM.lua

#### stSuicide (deprecated)
**Opcodes**: `0xFF`
- `SELFDESTRUCT` (0xFF) - Destroy contract

**Status**: ❌ Not yet implemented in EVM.lua

---

### Special Cases

#### stBadOpcode
**Purpose**: Tests invalid opcodes
**Opcodes**: Invalid/undefined opcodes

**Status**: ✅ Should fail gracefully

#### stZeroCallsTest
**Purpose**: Tests calls with zero value
**Opcodes**: `CALL`, `CALLCODE`, etc. with value=0

**Status**: 🔄 In progress

#### stRecursiveCreate
**Purpose**: Tests recursive contract creation
**Opcodes**: `CREATE` in recursive context

**Status**: ❌ Not yet implemented

---

## Test Priority Matrix

### Priority 1: Run Now (Fully Implemented)
```
✅ stStackTests          - Stack operations
✅ stArithmeticTest      - Arithmetic
✅ stBitwiseLogicOperation - Bitwise operations
✅ stMemoryTest          - Memory operations
✅ stSStoreTest          - Storage operations
✅ stJumpTest            - Control flow
✅ stEnvironmentalInfo   - Environment info
✅ stBlockHashTest       - Block info
✅ stKeccak256Test       - Hashing
✅ stLogTests            - Event logging
✅ stReturnDataTest      - Return operations (partial)
```

### Priority 2: Run with Caution (Partially Implemented)
```
🔄 stCallCodes           - Contract calls
🔄 stDelegatecallTest    - Delegate calls
🔄 stStaticCall          - Static calls
🔄 stZeroCallsTest       - Zero value calls
```

### Priority 3: Skip for Now (Not Implemented)
```
❌ stCreate2             - Contract creation
❌ stCreateTest          - CREATE opcode
❌ stRecursiveCreate     - Recursive creation
❌ stSuicide             - SELFDESTRUCT
```

---

## Running Tests by Implementation Status

### Run All Implemented Tests
```bash
cd tests
python3 eth-test-adapter.py /tmp/GeneralStateTests/stStackTests
python3 eth-test-adapter.py /tmp/GeneralStateTests/stArithmeticTest
python3 eth-test-adapter.py /tmp/GeneralStateTests/stMemoryTest
python3 eth-test-adapter.py /tmp/GeneralStateTests/stSStoreTest
python3 eth-test-adapter.py /tmp/GeneralStateTests/stLogTests
```

### Run Specific Opcode Tests
```bash
# Test only PUSH operations
cd /tmp/GeneralStateTests/stStackTests
python3 ../../tests/eth-test-adapter.py push*.json

# Test only arithmetic
cd /tmp/GeneralStateTests/stArithmeticTest
python3 ../../tests/eth-test-adapter.py add*.json
```

---

## Opcode Coverage Summary

| Opcode Range | Category | Tests Available | Status |
|--------------|----------|-----------------|--------|
| 0x00-0x0B | Stop & Arithmetic | ✅ Yes | ✅ Implemented |
| 0x10-0x1D | Comparison & Bitwise | ✅ Yes | ✅ Implemented |
| 0x20 | Keccak256 | ✅ Yes | ✅ Implemented |
| 0x30-0x3F | Environment | ✅ Yes | ✅ Implemented |
| 0x40-0x48 | Block Info | ✅ Yes | ✅ Implemented |
| 0x50-0x5F | Stack & Memory | ✅ Yes | ✅ Implemented |
| 0x60-0x7F | Push | ✅ Yes | ✅ Implemented |
| 0x80-0x8F | Dup | ✅ Yes | ✅ Implemented |
| 0x90-0x9F | Swap | ✅ Yes | ✅ Implemented |
| 0xA0-0xA4 | Log | ✅ Yes | ✅ Implemented |
| 0xF0-0xF5 | Create | ✅ Yes | ❌ Not Implemented |
| 0xF1-0xF4, 0xFA | Call | ✅ Yes | 🔄 In Progress |
| 0xF3, 0xFD | Return/Revert | ✅ Yes | ✅ Implemented |
| 0xFF | Selfdestruct | ✅ Yes | ❌ Not Implemented |

---

## Next Steps

1. Run Priority 1 tests to validate current implementation
2. Fix any failures in fully implemented opcodes
3. Complete Priority 2 opcodes (calls)
4. Implement Priority 3 opcodes (create, selfdestruct)
5. Run full test suite for 100% compliance
