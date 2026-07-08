# Precompile Feature Flag

## Overview

The EVM.lua implementation includes a feature flag to enable or disable precompiled contracts at runtime.

## Configuration

### Location

The feature flag is defined at the top of `evm.lua`:

```lua
-- Feature flags
EVM.ENABLE_PRECOMPILES = true  -- Set to false to disable precompiled contracts
```

### Default Value

**Default:** `true` (precompiles are ENABLED)

## Behavior

### When ENABLED (default)

- Calls to addresses `0x01` through `0x09` are routed to precompile handlers
- Precompile functions execute and return results
- Contracts using precompiles work as expected

### When DISABLED

- Calls to addresses `0x01` through `0x09` are treated as regular account calls
- These addresses are treated as EOAs (Externally Owned Accounts) with no code
- Calls succeed but return no data
- Useful for testing or debugging without precompile interference

## Use Cases

### 1. Testing Without Precompiles

Disable precompiles to test contract behavior when precompiles are unavailable:

```lua
EVM.ENABLE_PRECOMPILES = false
```

### 2. Debugging

Disable precompiles to isolate issues:
- Determine if a problem is in the precompile implementation
- Test contract logic without cryptographic operations
- Verify contract behavior with missing dependencies

### 3. Performance Testing

Compare performance with and without precompiles:
- Measure overhead of precompile routing
- Benchmark native vs. stub implementations

### 4. Gradual Rollout

Enable precompiles selectively during development:
- Start with precompiles disabled
- Enable when implementations are ready
- Test incrementally

## How to Change

### Method 1: Edit evm.lua

1. Open `evm.lua`
2. Find the line: `EVM.ENABLE_PRECOMPILES = true`
3. Change to: `EVM.ENABLE_PRECOMPILES = false`
4. Reload the EVM function in Redis:
   ```bash
   cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE
   ```

### Method 2: Dynamic Modification (for testing)

Use `sed` to modify on-the-fly:

```bash
# Disable precompiles
cat evm.lua | sed 's/EVM.ENABLE_PRECOMPILES = true/EVM.ENABLE_PRECOMPILES = false/' | redis-cli -x FUNCTION LOAD REPLACE

# Re-enable precompiles
cat evm.lua | redis-cli -x FUNCTION LOAD REPLACE
```

## Testing

### Run Feature Flag Tests

```bash
# Using make
make test-precompile-flag

# Direct execution
cd tests && ./test-precompile-flag.sh
```

### Test Coverage

The feature flag test suite verifies:
1. ✅ Precompiles work when enabled (default)
2. ✅ Precompiles are bypassed when disabled
3. ✅ Precompiles work again when re-enabled

### Example Test Output

```
Testing Precompile Feature Flag...
Redis server is already running.

✓ Precompiles ENABLED: Identity precompile executed successfully
✓ Precompiles DISABLED: Call to 0x04 treated as EOA (no precompile execution)
✓ Precompiles RE-ENABLED: Identity precompile works again

Precompile feature flag tests completed!
```

## Implementation Details

### Code Location

The feature flag is checked in `execute_contract_call()` function:

```lua
-- Check if this is a precompiled contract (if feature is enabled)
local addr_num = tonumber(addr_str, 16)
if EVM.ENABLE_PRECOMPILES and is_precompile(addr_num) then
    -- Execute precompiled contract
    local result = execute_precompile(addr_num, call_data)
    -- ... handle result
end
```

### Execution Flow

```
CALL to address 0x01-0x09
    ↓
Check EVM.ENABLE_PRECOMPILES
    ↓
If TRUE:                    If FALSE:
  ↓                           ↓
Execute precompile          Treat as regular account
  ↓                           ↓
Return result               Check for contract code
                              ↓
                            No code found (EOA)
                              ↓
                            Return success (no data)
```

## Best Practices

### Development

- Keep precompiles **ENABLED** during normal development
- Disable temporarily for specific debugging scenarios
- Document any non-default configuration

### Testing

- Test with both enabled and disabled states
- Verify contracts handle missing precompile results gracefully
- Include feature flag tests in CI/CD pipeline

### Production

- Keep precompiles **ENABLED** in production
- Only disable if specific compatibility issues arise
- Monitor contract behavior after any changes

## Troubleshooting

### Precompiles Not Working

**Symptom:** Calls to precompile addresses return no data

**Check:**
1. Verify `EVM.ENABLE_PRECOMPILES = true` in evm.lua
2. Reload EVM function in Redis
3. Run feature flag tests to verify

### Unexpected Behavior

**Symptom:** Contracts behave differently than expected

**Check:**
1. Verify feature flag state matches expectations
2. Check if precompile implementations are stubs or complete
3. Review contract assumptions about precompile availability

## Related Documentation

- [PRECOMPILES.md](../PRECOMPILES.md) - Complete precompile documentation
- [PRECOMPILE_IMPLEMENTATION_SUMMARY.md](../PRECOMPILE_IMPLEMENTATION_SUMMARY.md) - Implementation details
- [README.md](../README.md) - Main project documentation

## Future Enhancements

Potential improvements to the feature flag system:

1. **Per-Precompile Flags**
   - Enable/disable individual precompiles
   - Example: `EVM.ENABLE_ECRECOVER = true`

2. **Runtime Configuration**
   - Change flag without reloading EVM
   - Redis key-based configuration

3. **Logging**
   - Log when precompiles are called
   - Track usage statistics

4. **Fallback Behavior**
   - Custom behavior when disabled
   - Return specific error codes
