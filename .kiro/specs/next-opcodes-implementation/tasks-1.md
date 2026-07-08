
- [ ] 5. Update documentation and testing infrastructure
  - Update README with new opcode completion status
  - Enhance test framework for new operations
  - _Requirements: 7.5_

- [ ] 5.1 Create comprehensive test suite for all new opcodes
  - Add test files for each opcode category (arithmetic, bitwise, environmental, etc.)
  - Add edge case tests for stack underflow, memory bounds, and arithmetic overflow
  - Add integration tests for multi-opcode sequences
  - Add Redis state validation tests
  - _Requirements: 7.1, 7.4_

- [ ] 5.2 Update project documentation and opcode status
  - Update README.md opcode completion grid to reflect newly implemented opcodes
  - Add documentation for new Redis schema keys and patterns
  - Update installation and testing instructions if needed
  - Add examples of using new opcodes in the documentation
  - _Requirements: 7.5_

- [ ] 5.3 Enhance error handling and validation
  - Add comprehensive input validation for all new opcodes
  - Add proper error messages for edge cases and invalid operations
  - Add stack overflow protection for operations that push multiple values
  - Write tests for error handling and edge cases
  - _Requirements: 7.2, 7.4_



## Integration testing
- [ ] Load real data and make real complete eth_calls


## Critical improvements

- [ ] Optimize Lua call depth. 
      > For production: To support the full 1024 EVM call depth, you'd need an iterative implementation with an explicit call stack data structure, rather than relying on Lua's call stack.



## Nice to have

- [ ] Make library more standalone, less reliant on Redis


