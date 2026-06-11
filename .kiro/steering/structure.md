# Project Structure

## Root Directory

- `evm.lua` - Main EVM implementation (1096+ lines, complete interpreter)
- `Makefile` - Build system with test targets
- `README.md` - Project documentation with opcode implementation status
- `LICENSE` - Project license
- `dump.rdb` - Redis database dump file

## Core Directories

### `/instructions/` - Python Reference Implementation (temporary, will be deleted later)
Modular Python implementation organized by opcode categories:
- `__init__.py` - Opcode enum definitions and instruction mapping
- `arithmetic.py` - ADD, SUB, MUL, DIV, MOD, EXP operations
- `bitwise.py` - AND, OR, XOR, NOT, SHL, SHR operations
- `comparison.py` - LT, GT, EQ, ISZERO comparison operations
- `stack.py` - PUSH, POP, DUP, SWAP stack operations
- `memory.py` - MLOAD, MSTORE, MSIZE memory operations
- `storage.py` - SLOAD, SSTORE storage operations
- `control_flow.py` - JUMP, JUMPI, STOP control flow
- `environment.py` - ADDRESS, CALLER, CALLDATA context operations
- `block.py` - BLOCKHASH, TIMESTAMP, NUMBER block operations
- `keccak.py` - KECCAK256 hashing operations
- `log.py` - LOG0-LOG4 event logging operations
- `system.py` - CALL, RETURN, CREATE system operations

### `/tests/` - Test Suite
Comprehensive bash-based testing framework:
- `lib.sh` - Shared testing utilities and Redis helpers
- `run-all-tests.sh` - Master test runner
- `test-*.sh` - Individual opcode category tests
- `dump.rdb` - Test database state

### `/scripts/` - Utility Scripts
Performance and debugging tools:
- `benchmark-redis.py` - Redis performance benchmarking
- `benchmark-rpc.py` - RPC performance testing
- `export-contract-state.py` - Contract state export utilities
- `export-contract-state-delta.py` - State delta analysis

### `/references/` - Reference Materials
- `sha3.ts` - TypeScript SHA3 reference implementation
- `uniswap-token-opcodes.txt` - Real-world bytecode examples

## File Organization Patterns

- **Single File Architecture**: Main EVM logic consolidated in `evm.lua`
- **Test-Driven Structure**: Each opcode category has corresponding test file
- **Utility Separation**: Scripts and references kept in dedicated directories
- **Redis Integration**: Database dumps and state management files at root level

## Key Files for Development

- `evm.lua` - Primary implementation file for all EVM logic
- `tests/lib.sh` - Essential testing utilities and Redis setup
- `instructions/__init__.py` - Complete opcode reference and mapping
- `Makefile` - Build and test automation
