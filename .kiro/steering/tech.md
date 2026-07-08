# Technology Stack

## Core Technologies

- **Primary Language**: Lua scripting language
- **Database**: Redis for state storage and execution context
- **Testing**: Bash shell scripts with Redis CLI integration
- **Build System**: Make-based build system

## Dependencies

- **Lua**: Core scripting runtime
- **luarocks**: Lua package manager
- **Redis**: In-memory database for contract storage
- **redis-cli**: Command-line interface for Redis operations

## Architecture

- **Monolithic Design**: Single `evm.lua` file contains the complete EVM implementation
- **Modular Instructions**: Python reference implementation (not truly part of this project) organized by instruction categories:
  - `instructions/arithmetic.py` - Math operations
  - `instructions/bitwise.py` - Bitwise operations  
  - `instructions/stack.py` - Stack manipulation
  - `instructions/memory.py` - Memory operations
  - `instructions/storage.py` - Storage operations
  - `instructions/control_flow.py` - Jump and control flow
  - `instructions/environment.py` - Blockchain context
  - `instructions/system.py` - System calls and contract interaction

## Common Commands

### Setup
```bash
# Install dependencies
brew install lua luarocks redis

# Start Redis server
redis-server

# Load EVM into Redis
./load.sh
```

### Testing
```bash
# Run all tests
make test


# Important: run all tests every time! if Kiro is on autopilot, it might get stuck unnecessarily.

# Run specific test suites
make test-stack
cd tests && ./test-arithmetic.sh
cd tests && ./run-all-tests.sh
```

### Development
```bash
# Watch for changes and run tests
cd tests
fswatch -o ../ | xargs -n1 -I{} ./test-arithmetic.sh
```

## Code Patterns

- **Opcode Implementation**: Each opcode is a function that modifies EVM state
- **State Management**: EVM state includes stack, memory, storage, PC, and logs
- **Redis Integration**: Contract bytecode and storage stored as Redis keys
- **Hex Handling**: Extensive hex string manipulation and conversion utilities