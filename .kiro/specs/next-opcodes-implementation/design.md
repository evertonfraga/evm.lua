# Design Document

## Overview

This design outlines the implementation of 35 missing EVM opcodes to achieve near-complete EVM compliance in the Lua-based implementation. The design maintains the existing Redis-backed architecture while adding support for critical arithmetic, bitwise, environmental, block context, memory, and system operations.

The implementation follows the established patterns in the current `evm.lua` file, using the `EVM.opcodes` table structure with function implementations that manipulate the EVM state object containing stack, memory, storage, program counter, and logs.

## Architecture

### Current Architecture Analysis

The existing EVM.lua implementation uses:
- **State Management**: EVM state object with `stack`, `memory`, `storage`, `pc`, `logs`, and `return_data`
- **Opcode Dispatch**: Table-based dispatch using `EVM.opcodes[opcode_value] = function(state, bytecode)`
- **Redis Integration**: External state stored in Redis (CALLER, CALLVALUE, CALLDATA, etc.)
- **Stack Operations**: Lua table operations with `table.insert()` and `table.remove()`
- **Hex Handling**: Custom `h()` function for hex formatting and `toNumber()` for conversions

### Design Principles

1. **Consistency**: Follow existing patterns for opcode implementation
2. **Redis Integration**: Use Redis for external blockchain context data
3. **Error Handling**: Proper stack underflow and overflow checks
4. **Precision**: Handle large numbers using hex strings when needed
5. **Testing**: Each opcode must be testable through the existing test framework

## Components and Interfaces

### 1. Arithmetic Operations Component

**Missing Opcodes**: 0x07 (SMOD), 0x08 (ADDMOD), 0x09 (MULMOD), 0x0B (SIGNEXTEND)

**Interface Design**:
```lua
-- SMOD (0x07): Signed modulo operation
[0x07] = function(state)
    local a = toNumber(table.remove(state.stack))
    local b = toNumber(table.remove(state.stack))
    -- Handle signed arithmetic with proper overflow
    -- Push result to stack
    state.pc = state.pc + 1
end
```

**Key Considerations**:
- Signed arithmetic requires proper handling of negative numbers
- ADDMOD and MULMOD require three stack operands
- SIGNEXTEND requires bit manipulation for sign extension

### 2. Bitwise Operations Component

**Missing Opcodes**: 0x18 (XOR), 0x1A (BYTE), 0x1B (SHL), 0x1D (SAR)

**Interface Design**:
```lua
-- XOR (0x18): Bitwise exclusive OR
[0x18] = function(state)
    local a = toNumber(table.remove(state.stack))
    local b = toNumber(table.remove(state.stack))
    table.insert(state.stack, a ~ b)  -- Lua bitwise XOR
    state.pc = state.pc + 1
end
```

**Key Considerations**:
- BYTE operation requires extracting specific bytes from 32-byte words
- Shift operations need to handle large shift amounts properly
- SAR (arithmetic right shift) must preserve sign bit

### 3. Environmental Context Component

**Missing Opcodes**: 0x31 (BALANCE), 0x32 (ORIGIN), 0x37 (CALLDATACOPY), 0x38 (CODESIZE), 0x3B (EXTCODESIZE), 0x3C (EXTCODECOPY), 0x3F (EXTCODEHASH)

**Interface Design**:
```lua
-- BALANCE (0x31): Get account balance
[0x31] = function(state)
    local address = table.remove(state.stack)
    local balance = redis.call("GET", "BALANCE:" .. address) or 0
    table.insert(state.stack, toNumber(balance))
    state.pc = state.pc + 1
end
```

**Redis Schema Extensions**:
- `BALANCE:<address>` - Account balances
- `ORIGIN` - Transaction origin address  
- `CODE:<address>` - Contract bytecode
- `CODEHASH:<address>` - Contract code hashes

### 4. Memory Operations Component

**Missing Opcodes**: 0x58 (PC), 0x59 (MSIZE), 0x5C (TLOAD), 0x5D (TSTORE), 0x5E (MCOPY)

**Interface Design**:
```lua
-- MSIZE (0x59): Memory size
[0x59] = function(state)
    local size = #state.memory
    table.insert(state.stack, size)
    state.pc = state.pc + 1
end
```

**State Extensions**:
- Add `transient_storage` table to EVM state for TLOAD/TSTORE
- MCOPY requires memory-to-memory copying with proper bounds checking

### 5. System Operations Component

**Missing Opcodes**: 0xF0 (CREATE), 0xF1 (CALL), 0xF2 (CALLCODE), 0xF4 (DELEGATECALL), 0xF5 (CREATE2), 0xFF (SELFDESTRUCT)

**Interface Design**:
```lua
-- CREATE (0xF0): Create new contract
[0xF0] = function(state)
    local value = toNumber(table.remove(state.stack))
    local offset = toNumber(table.remove(state.stack))
    local length = toNumber(table.remove(state.stack))
    -- Contract creation logic
    -- Push new contract address to stack
    state.pc = state.pc + 1
end
```

**Key Considerations**:
- System operations require complex state management
- CALL operations need nested execution context support

## Data Models

### Enhanced EVM State Model

```lua
local evmState = {
    address = addr,
    stack = {},
    memory = {},
    storage = {},
    transient_storage = {},  -- New for TLOAD/TSTORE
    pc = 1,
    logs = {},
    return_data = {},
    call_depth = 0,  -- New for nested calls
    created_contracts = {}  -- New for CREATE operations
}
```

### Redis Data Schema

**Existing Keys**:
- `CALLER`, `CALLVALUE`, `CALLDATA`, `GASPRICE`, `CHAINID`, `NUMBER`, `TIMESTAMP`, `GAS`

**New Keys**:
- `BALANCE:<address>` - Account balances
- `ORIGIN` - Transaction origin
- `CODE:<address>` - Contract bytecode  
- `CODEHASH:<address>` - Contract code hashes

## Error Handling

### Stack Underflow Protection

```lua
local function safe_pop(stack, count)
    if #stack < count then
        error("Stack underflow")
    end
    local values = {}
    for i = 1, count do
        table.insert(values, table.remove(stack))
    end
    return table.unpack(values)
end
```

### Memory Bounds Checking

```lua
local function safe_memory_access(memory, offset, length)
    -- Ensure memory is properly expanded
    local required_size = offset + length
    while #memory < required_size do
        table.insert(memory, 0)
    end
end
```

### Invalid Opcode Handling

All unimplemented opcodes should follow the existing pattern:
```lua
-- For invalid/unimplemented opcodes
state.running = false
state.invalid_opcode = true
error("Invalid opcode: " .. h(opcode))
```

## Testing Strategy

### Unit Testing Approach

1. **Individual Opcode Tests**: Each opcode gets dedicated test cases in the existing bash test framework
2. **Edge Case Testing**: Stack underflow, memory bounds, arithmetic overflow
3. **Integration Testing**: Multi-opcode sequences that test interaction between operations
4. **Redis State Testing**: Verify proper Redis key usage and state persistence

### Test File Structure

Following existing patterns:
- `tests/test-arithmetic-extended.sh` - New arithmetic operations
- `tests/test-bitwise-extended.sh` - New bitwise operations  
- `tests/test-environment-extended.sh` - New environmental operations
- `tests/test-system-operations.sh` - System call operations

### Test Data Requirements

**Redis Test Data Setup**:
```bash
# In test setup
redis-cli SET "BALANCE:0x1234567890123456789012345678901234567890" 1000000000000000000
redis-cli SET "ORIGIN" "0x0000000000000000000000000000000000000001"
redis-cli SET "COINBASE" "0x0000000000000000000000000000000000000002"
```

## Implementation Phases

### Phase 1: Core Missing Operations (Priority 1)
- Arithmetic: SMOD, ADDMOD, MULMOD, SIGNEXTEND
- Bitwise: XOR, BYTE, SHL, SAR
- Memory: PC, MSIZE

### Phase 2: Environmental Context (Priority 2)  
- BALANCE, ORIGIN, CALLDATACOPY, CODESIZE
- Block context: COINBASE, PREVRANDAO, GASLIMIT, SELFBALANCE, BASEFEE

### Phase 3: Advanced Operations (Priority 3)
- External code operations: EXTCODESIZE, EXTCODECOPY, EXTCODEHASH
- Transient storage: TLOAD, TSTORE
- Memory copy: MCOPY

### Phase 4: System Operations (Priority 4)
- Contract calls: CALL, CALLCODE, DELEGATECALL, STATICCALL

## Performance Considerations

### Memory Management
- Lazy memory expansion to avoid unnecessary allocations
- Efficient memory copying for MCOPY and CALLDATACOPY operations

### Redis Optimization
- Batch Redis operations where possible
- Use Redis pipelining for multiple key operations
- Consider Redis data structure optimization for frequently accessed data

### Large Number Handling
- Continue using hex string representation for numbers > 7 bytes
- Implement efficient arithmetic operations on hex strings for large values

## Security Considerations

### Input Validation
- Validate all stack operands before arithmetic operations
- Check memory bounds before all memory operations
- Validate addresses before external code operations

### State Isolation
- Ensure transient storage is properly isolated between transactions
- Prevent unauthorized access to other contract storage
- Proper cleanup of created contract state on failure

### Gas Metering Preparation
- Design opcodes with future gas metering in mind
- Track operation complexity for future gas cost implementation
- Ensure all operations can be properly metered when gas system is added