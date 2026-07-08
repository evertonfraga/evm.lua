# Product Overview

EVM.lua is a fully compliant Ethereum Virtual Machine implementation written in Lua scripting language. The project provides scripts to bind the EVM to a Redis database, enabling it to run EVM functions at scale.

## Key Features

- **EVM Compliance**: Implements 117 out of 152 EVM opcodes with full bytecode interpretation
- **Redis Integration**: Uses Redis as the backend storage for contract state and execution context
- **Scalable Architecture**: Designed to handle EVM execution at scale through Redis
- **Comprehensive Testing**: Extensive test suite covering all implemented opcodes

## Current Status

- ✅ Core EVM bytecode interpreter
- ✅ Account storage management based on initial state and block number
- ✅ Basic benchmark scripts for performance testing
- ⏳ Nested call context (in progress)
- ⏳ Gas metering system (planned)

## Use Cases

- Execution of high-volume, complex EVM read operations, in a production-ready setup