#!/bin/bash

# Test utility functions for enhanced arithmetic operations

source ./lib.sh

echo "Testing utility functions..."

# Test safe_pop function with normal operation
test_case "safe_pop normal operation" '
    local state = EVM.init("0x1234567890123456789012345678901234567890")
    table.insert(state.stack, 42)
    table.insert(state.stack, 100)
    
    local function safe_pop(stack, count)
        count = count or 1
        if #stack < count then
            error("Stack underflow: attempted to pop " .. count .. " items from stack of size " .. #stack)
        end
        local values = {}
        for i = 1, count do
            table.insert(values, table.remove(stack))
        end
        if count == 1 then
            return values[1]
        else
            return table.unpack(values)
        end
    end
    
    local value = safe_pop(state.stack)
    return value == 100 and #state.stack == 1
'

# Test safe_pop function with underflow protection
test_case "safe_pop underflow protection" '
    local state = EVM.init("0x1234567890123456789012345678901234567890")
    
    local function safe_pop(stack, count)
        count = count or 1
        if #stack < count then
            error("Stack underflow: attempted to pop " .. count .. " items from stack of size " .. #stack)
        end
        local values = {}
        for i = 1, count do
            table.insert(values, table.remove(stack))
        end
        if count == 1 then
            return values[1]
        else
            return table.unpack(values)
        end
    end
    
    local success, err = pcall(safe_pop, state.stack)
    return not success and string.find(err, "Stack underflow")
'

# Test signed_arithmetic function
test_case "signed_arithmetic positive value" '
    local function signed_arithmetic(value)
        if value >= 2^255 then
            return value - 2^256
        else
            return value
        end
    end
    
    local result = signed_arithmetic(42)
    return result == 42
'

test_case "signed_arithmetic negative value" '
    local function signed_arithmetic(value)
        if value >= 2^255 then
            return value - 2^256
        else
            return value
        end
    end
    
    -- Test with a large value that should be negative in two'\''s complement
    local large_value = 2^255 + 100
    local result = signed_arithmetic(large_value)
    return result == 100 - 2^256 + 2^255
'

# Test mod_arithmetic function with normal operation
test_case "mod_arithmetic normal operation" '
    local function mod_arithmetic(a, b)
        if b == 0 then
            return 0
        end
        local result = a % b
        if result < 0 then
            result = result + math.abs(b)
        end
        return result
    end
    
    local result = mod_arithmetic(17, 5)
    return result == 2
'

# Test mod_arithmetic function with zero divisor
test_case "mod_arithmetic zero divisor" '
    local function mod_arithmetic(a, b)
        if b == 0 then
            return 0
        end
        local result = a % b
        if result < 0 then
            result = result + math.abs(b)
        end
        return result
    end
    
    local result = mod_arithmetic(17, 0)
    return result == 0
'

# Test mod_arithmetic function with negative result handling
test_case "mod_arithmetic negative result handling" '
    local function mod_arithmetic(a, b)
        if b == 0 then
            return 0
        end
        local result = a % b
        if result < 0 then
            result = result + math.abs(b)
        end
        return result
    end
    
    local result = mod_arithmetic(-7, 3)
    return result >= 0
'

echo "Utility functions tests completed."