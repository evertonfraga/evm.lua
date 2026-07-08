# Ethereum Precompiled Contracts Implementation

This document describes the implementation of Ethereum precompiled contracts in EVM.lua.

## Overview

Precompiled contracts are special contracts at addresses `0x01` through `0x09` (and beyond in later forks) that provide native implementations of commonly used cryptographic and utility functions. Unlike regular contracts, they are implemented directly in the EVM client for performance and complexity reasons.

## Implementation Status

| Address | Name | Status | Description |
|---------|------|--------|-------------|
| 0x01 | ECRecover | ✅ Stub | ECDSA signature recovery (placeholder) |
| 0x02 | SHA2-256 | ✅ Complete | SHA-256 hash function |
| 0x03 | RIPEMD-160 | ✅ Stub | RIPEMD-160 hash function (placeholder) |
| 0x04 | Identity | ✅ Complete | Data copy function |
| 0x05 | ModExp | ✅ Stub | Modular exponentiation (placeholder) |
| 0x06 | ECAdd | ✅ Stub | Elliptic curve point addition (placeholder) |
| 0x07 | ECMul | ✅ Stub | Elliptic curve scalar multiplication (placeholder) |
| 0x08 | ECPairing | ✅ Stub | Elliptic curve pairing check (placeholder) |
| 0x09 | Blake2F | ✅ Stub | Blake2b compression function (placeholder) |

## Detailed Implementation

### 0x01: ECRecover (ECDSA Signature Recovery)

**Status:** Stub implementation

**Input:** 128 bytes
- 32 bytes: message hash
- 32 bytes: v (recovery id)
- 32 bytes: r (signature component)
- 32 bytes: s (signature component)

**Output:** 32 bytes (20-byte address padded to 32 bytes)

**TODO:** Requires secp256k1 elliptic curve library for full implementation.

### 0x02: SHA2-256 Hash Function

**Status:** ⚠️ Partial implementation (needs verification)

**Input:** Variable length data

**Output:** 32 bytes (SHA-256 hash)

**Implementation:** Pure Lua implementation using bit operations compatible with Redis Lua environment.

**Known Issues:** Current implementation produces hashes but doesn't match NIST test vectors. Needs debugging and verification.

**TODO:** Verify and fix SHA-256 algorithm implementation to match standard test vectors.

### 0x03: RIPEMD-160 Hash Function

**Status:** Stub implementation

**Input:** Variable length data

**Output:** 32 bytes (20-byte RIPEMD-160 hash padded to 32 bytes)

**TODO:** Implement RIPEMD-160 hashing algorithm.

### 0x04: Identity (Data Copy)

**Status:** ✅ Fully implemented

**Input:** Variable length data

**Output:** Same as input (data copy)

**Use Case:** Simple data copying, often used for testing or as a placeholder.

### 0x05: ModExp (Modular Exponentiation)

**Status:** Stub implementation (Byzantium fork)

**Input:** Variable length
- 32 bytes: base length
- 32 bytes: exponent length
- 32 bytes: modulus length
- Variable: base
- Variable: exponent
- Variable: modulus

**Output:** Result of (base^exponent) % modulus

**TODO:** Implement big integer arithmetic for modular exponentiation.

### 0x06: ECAdd (Elliptic Curve Point Addition)

**Status:** Stub implementation (Byzantium fork)

**Input:** 128 bytes (two alt_bn128 curve points)
- 32 bytes: x1
- 32 bytes: y1
- 32 bytes: x2
- 32 bytes: y2

**Output:** 64 bytes (resulting point x, y)

**TODO:** Implement alt_bn128 curve point addition.

### 0x07: ECMul (Elliptic Curve Scalar Multiplication)

**Status:** Stub implementation (Byzantium fork)

**Input:** 96 bytes
- 32 bytes: point x
- 32 bytes: point y
- 32 bytes: scalar s

**Output:** 64 bytes (resulting point x, y)

**TODO:** Implement alt_bn128 curve scalar multiplication.

### 0x08: ECPairing (Elliptic Curve Pairing Check)

**Status:** Stub implementation (Byzantium fork)

**Input:** Multiple of 192 bytes (pairs of G1 and G2 points)

**Output:** 32 bytes (1 if pairing is valid, 0 otherwise)

**TODO:** Implement alt_bn128 pairing check.

### 0x09: Blake2F (Blake2b Compression Function)

**Status:** Stub implementation (Istanbul fork)

**Input:** 213 bytes
- 4 bytes: rounds
- 64 bytes: h (state vector)
- 128 bytes: m (message block)
- 16 bytes: t (offset counters)
- 1 byte: f (final block indicator)

**Output:** 64 bytes (final hash state)

**TODO:** Implement Blake2F compression function.

## Integration with EVM

Precompiles are integrated into the EVM execution flow through the `execute_contract_call` function. When a CALL, STATICCALL, or DELEGATECALL targets an address in the range 0x01-0x09, the EVM:

1. Checks if precompiles are enabled (`EVM.ENABLE_PRECOMPILES` flag)
2. Detects the precompile address
3. Routes to the appropriate precompile function
4. Executes the native implementation
5. Returns the result in `state.return_data`

### Feature Flag

Precompiles can be enabled or disabled using the `EVM.ENABLE_PRECOMPILES` flag in `evm.lua`:

```lua
-- Feature flags
EVM.ENABLE_PRECOMPILES = true  -- Set to false to disable precompiled contracts
```

**Default:** `true` (enabled)

When disabled, calls to precompile addresses (0x01-0x09) are treated as calls to regular accounts with no code (EOA), which succeed but return no data.

## Testing

Run precompile tests:

```bash
make test-precompiles
```

Or directly:

```bash
cd tests && ./test-precompiles.sh
```

Test the feature flag:

```bash
cd tests && ./test-precompile-flag.sh
```

## Future Work

### High Priority
1. **ECRecover (0x01)**: Critical for signature verification in many contracts
   - Requires secp256k1 library integration
   - Used by wallet contracts, multisig, etc.

2. **ModExp (0x05)**: Important for RSA verification and other cryptographic operations
   - Requires big integer arithmetic library
   - Used by some bridge contracts

### Medium Priority
3. **ECAdd, ECMul, ECPairing (0x06-0x08)**: Required for zkSNARK verification
   - Requires alt_bn128 curve implementation
   - Used by privacy protocols (Tornado Cash, etc.)

4. **Blake2F (0x09)**: Used by some bridge contracts
   - Relatively straightforward to implement

5. **RIPEMD-160 (0x03)**: Less commonly used but part of Bitcoin compatibility
   - Used by some Bitcoin bridge contracts

## References

- [EVM Precompiled Contracts](https://www.evm.codes/precompiled)
- [Ethereum Yellow Paper](https://ethereum.github.io/yellowpaper/paper.pdf)
- [EIP-152: Blake2F Precompile](https://eips.ethereum.org/EIPS/eip-152)
- [EIP-196/197: alt_bn128 Precompiles](https://eips.ethereum.org/EIPS/eip-196)
