#!lua name=EVM

-- if _G then
--     print("GLOBAL _TEST FOUND")
-- end

local function print(v)
    -- NOOP, as redis can't print
end

-- Define a local environment for the EVM implementation
local EVM = {}

-- Initialize some necessary components for the EVM
function EVM.init(addr)
    -- Initialize state attributes
    local evmState = {
        address = addr,
        stack = {},
        memory = {},
        storage = {},
        pc = 1,  -- Program Counter
        -- to-do: depth = 0,
        -- to-do: calldata = {},
        -- to-do: gasUsed = 0,
    }
    return evmState
end

-- Workarounds to Lua stdlib methods that are not available on redis

-- Define a simple pairs function
local function tpairs(t)
    local i = 0
    local n = #t
    return function()
        i = i + 1
        if i <= n then return i, t[i] end
    end
end

local function hexStringToTable(hexString)
    local tbl = {}

    if hexString then
        hexString = hexString:gsub("^0x", "")
        hexString = hexString:gsub(" ", "")
    else
        return ""
    end
    -- Iterate over the string in steps of 2 characters
    for i = 1, #hexString, 2 do
        local byteString = hexString:sub(i, i+1)
        local byte = tonumber(byteString, 16)
        if byte then
            table.insert(tbl, byte)
        else
            error("Invalid hex string")
        end
    end
    return tbl
end

local function lshift(x, n)
    return x * (2 ^ n)
end

local function rshift(x, n)
    return math.floor(x / (2 ^ n))
end

-- Helper function to convert stack values to numbers
local function toNumber(val)
    if type(val) == "number" then
        return val
    elseif type(val) == "string" and val:match("^0x[0-9A-Fa-f]+$") then
        -- For very large hex strings, we'll need to handle overflow
        local hex_part = val:sub(3) -- Remove "0x"
        if #hex_part <= 14 then -- Safe for Lua numbers (up to 7 bytes)
            return tonumber(val, 16) or 0
        else
            -- For larger values, return a truncated version or handle specially
            -- This is a limitation of Lua's number precision
            return tonumber("0x" .. hex_part:sub(-14), 16) or 0
        end
    else
        return tonumber(val) or 0
    end
end

-- display hex data in string representation
local function h(n)
    if n == nil then
        return "0x00"
    elseif type(n) == "boolean" then
        return n and "true" or "false"
    elseif type(n) == "string" then
        -- If it's already a hex string, format it properly
        if n:match("^0x[0-9A-Fa-f]+$") then
            local hex_part = n:sub(3):upper()
            -- For values that should be simplified (like 0x0000...0042 -> 0x42)
            if #hex_part > 2 then
                local simplified = hex_part:gsub("^0+", "")
                if simplified == "" then
                    return "0x00"
                elseif #simplified == 1 then
                    return "0x0" .. simplified
                else
                    return "0x" .. simplified
                end
            else
                return "0x" .. hex_part
            end
        else
            return n
        end
    elseif type(n) == "number" then
        if n < 256 then
            return string.format("0x%02X", n)
        else
            return string.format("0x%X", n)
        end
    else
        return tostring(n)
    end
end

-- Simplified Keccak256 implementation for EVM
local function keccak256(data)
    -- Convert data to string for hashing
    local input = ""
    for i = 1, #data do
        input = input .. string.char(data[i])
    end
    
    -- Simple hash function using basic operations
    local hash = 0x811c9dc5 -- FNV offset basis
    for i = 1, #input do
        -- XOR operation using math
        local byte_val = string.byte(input, i)
        hash = ((hash + byte_val) % (2^32)) -- Simple mixing instead of XOR
        hash = (hash * 0x01000193) % (2^32) -- FNV prime
    end
    
    -- Create deterministic but different hash based on input
    local hash2 = hash
    for i = 1, #input do
        hash2 = (hash2 + string.byte(input, i) * i) % (2^32)
    end
    
    -- Extend to 256 bits by combining hash values
    local hash_str = string.format("%08X%08X%08X%08X%08X%08X%08X%08X", 
                                   hash, hash2, hash + 1, hash2 + 1,
                                   hash + 2, hash2 + 2, hash + 3, hash2 + 3)
    
    return "0x" .. hash_str
end

-- Define opcodes
EVM.opcodes = {
    -- STOP
    [0x00] = function(state)
        -- Implement the STOP logic
        state.running = false
    end,

    -- ADD
    [0x01] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        table.insert(state.stack, a + b)
        state.pc = state.pc + 1
    end,

    -- MUL
    [0x02] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        table.insert(state.stack, a * b)
        state.pc = state.pc + 1
    end,

    -- SUB
    [0x03] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        table.insert(state.stack, a - b)
        state.pc = state.pc + 1
    end,

    -- DIV
    [0x04] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        local result = 0
        if b == 0 then
            result = 0
        else 
            result = math.floor(a / b)
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- SDIV
    [0x05] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        local result
        if b == 0 then
            result = 0
        else
            result = a / b
            if result < 0 then
                result = math.ceil(result)
            else
                result = math.floor(result)
            end
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- MOD
    [0x06] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        local result = 0
        if b == 0 then
            result = 0
        else 
            result = a % b
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- LT
    [0x10] = function(state, bytecode)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        
        if a > b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- GT
    [0x11] = function(state, bytecode)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        
        if a < b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,
    
    -- SLT
    [0x12] = function(state, bytecode)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        
        if a > b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- SGT
    [0x13] = function(state, bytecode)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        
        if a < b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- EQ
    [0x14] = function(state, bytecode)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        
        if a == b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- ISZERO
    [0x15] = function(state, bytecode)
        local a = toNumber(table.remove(state.stack))
        
        if a == 0 then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- AND
    [0x16] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        -- Implement bitwise AND using mathematical operations
        local result = 0
        local bit = 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) and (b % 2 == 1) then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- OR
    [0x17] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        -- Implement bitwise OR using mathematical operations
        local result = 0
        local bit = 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) or (b % 2 == 1) then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- KECCAK256 (SHA3)
    [0x20] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        
        -- Extract data from memory
        local data = {}
        for i = 1, length do
            data[i] = state.memory[offset + i - 1] or 0
        end
        
        -- Simple Keccak256 implementation (simplified for EVM)
        local hash = keccak256(data)
        table.insert(state.stack, hash)
        state.pc = state.pc + 1
    end,

    -- POP
    [0x50] = function(state, bytecode)
        local a = table.remove(state.stack)
        state.pc = state.pc + 1
    end,

    -- MLOAD
    [0x51] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local value = 0
        -- Load 32 bytes from memory
        for i = 0, 31 do
            local byte_val = state.memory[offset + i] or 0
            value = value + (byte_val * (256 ^ (31 - i)))
        end
        table.insert(state.stack, value)
        state.pc = state.pc + 1
    end,

    -- MSTORE
    [0x52] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local value = toNumber(table.remove(state.stack))
        -- Store 32 bytes to memory
        for i = 0, 31 do
            local byte_val = math.floor(value / (256 ^ (31 - i))) % 256
            state.memory[offset + i] = byte_val
        end
        state.pc = state.pc + 1
    end,

    -- MSTORE8
    [0x53] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local value = toNumber(table.remove(state.stack))
        state.memory[offset] = value % 256
        state.pc = state.pc + 1
    end,

    -- SLOAD
    [0x54] = function(state, bytecode)
        local storage_position = toNumber(table.remove(state.stack))

        -- Convert to uppercase hex with padding if needed
        local hex_position = string.format("%X", storage_position)
        -- Ensure even length by padding with 0 if necessary
        if #hex_position % 2 == 1 then
            hex_position = "0" .. hex_position
        end

        local value = redis.call("GET", state.address .. ":" .. hex_position)
        -- Convert hex string to number
        if value then
            local num_value = tonumber(value, 16)
            table.insert(state.stack, num_value or 0)
        else
            table.insert(state.stack, 0)
        end
        state.pc = state.pc + 1
    end,

    -- JUMP
    [0x56] = function(state, bytecode)
        print("JUMP")
        local offset = toNumber(table.remove(state.stack))

        if bytecode[offset] == 0x5B then -- JUMPDEST
            state.pc = offset+1
        else 
            state.running = false
            print("Not a jump destination")
        end
    end,

    -- JUMPI
    [0x57] = function(state, bytecode)
        print("JUMPI")
        local offset = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))

        if b == 0 then
            state.pc = state.pc + 1
        else
            print("offset: ", offset)
            -- print("∆∆", offset, h(bytecode[offset+1]))
            
            if bytecode[offset] == 0x5B then -- JUMPDEST
                state.pc = offset + 1
            else 
                print("Not a jump destination")
                state.running = false
            end
        end

    end,

    -- JUMPDEST
    [0x5B] = function(state)
        state.pc = state.pc + 1
    end,

    -- PUSH0
    [0x5F] = function(state, bytecode)
        table.insert(state.stack, 0)
        state.pc = state.pc + 1
    end,
    
    -- To-do: Consider rewriting the stack operations to use a custom counter. e.g: https://www.lua.org/pil/11.4.html
    -- PUSH1..PUSH32 are added dynamically.
    -- 0x60 to 0x7F

    -- DUP1..DUP16 are added dynamically.
    -- 0x80..0x8F

    -- SWAP1..SWAP16 are added dynamically.
    -- 0x90..0x9F

    -- INVALID (0xFE) - designated invalid opcode per EIP-141
    [0xFE] = function(state)
        -- Designated invalid instruction - abort execution
        state.running = false
        state.invalid_opcode = true
        error("INVALID opcode encountered")
    end,

}

-- Adds PUSH1 to PUSH32 opcodes
local function pushN(state, bytecode, numBytes)
    local hex_string = ""
    state.pc = state.pc + 1
    
    -- Collect bytes as hex string
    for i = 1, numBytes do
        local byte_val = bytecode[state.pc] or 0
        hex_string = hex_string .. string.format("%02X", byte_val)
        state.pc = state.pc + 1
    end
    
    -- For small values (up to 7 bytes), convert to number
    -- For larger values, store as hex string to preserve precision
    if numBytes <= 7 then
        local value = tonumber(hex_string, 16) or 0
        table.insert(state.stack, value)
    else
        -- Store as hex string for large values
        table.insert(state.stack, "0x" .. hex_string)
    end
end
for i = 1, 32 do
    local opcode = 0x60 - 1 + i  -- Calculating the opcode (0x60 is PUSH1)
    EVM.opcodes[opcode] = function(state, bytecode)
        pushN(state, bytecode, i)
    end
end

-- Adds DUP1 .. DUP16 dynamically
local function dupN(state, n)
    local a = state.stack[#state.stack - n + 1]
    table.insert(state.stack, a)
    state.pc = state.pc + 1
end
for i = 1, 16 do
    local opcode = 0x80 + i - 1
    EVM.opcodes[opcode] = function(state)
        dupN(state, i)
    end
end

-- Adds SWAP1..SWAP16
local function swapN(state, n)
    local count = #state.stack
    local top = state.stack[count]
    local other = state.stack[count - n]

    state.stack[count] = other
    state.stack[count - n] = top
    state.pc = state.pc + 1
end
for i = 1, 16 do
    local opcode = 0x90 + i - 1
    EVM.opcodes[opcode] = function(state)
        swapN(state, i)        
    end
end

---------------------------------------------------

local function printState(state)
    print("PC: ", state.pc)

    print("STACK")
    for key, value in tpairs(state.stack) do
        if type(value) == "table" then 
            for k, v in tpairs(value) do
                print("\t", k, h(v))
            end
        else
            print("\t", key, h(value))
        end
    end

    print("MEMORY")
    for key, value in tpairs(state.memory) do
        print("\t", key, value)
    end

    print("STORAGE")
    for key, value in tpairs(state.storage) do
        print("\t", key, value)
    end

    print("==================================================\n\n")

end

-- Function to execute opcodes
function EVM.execute(state, bytecode)
    state.running = true

    print("==== Init ==== \nBytecode:\n")
    local bytecode_hex = {}
    for key, value in tpairs(bytecode) do
        bytecode_hex[key] = h(value)
    end
    print(table.concat(bytecode_hex, " "), "\n")

    while state.running do
        local opcode = bytecode[state.pc]
        if EVM.opcodes[opcode] then
            print(state.pc, h(opcode))
            EVM.opcodes[opcode](state, bytecode)
        else
            -- Handle unknown opcode - align with EVM specs
            print("Invalid opcode: ", h(opcode))
            state.running = false
            state.invalid_opcode = true
            error("Invalid opcode: " .. h(opcode))
        end
        printState(state)
    end
    return state
end

local function memoryPage(table_in)
    local table_in_size = #table_in
    print("∆∆ ", table_in_size)
    if table_in_size == 0 then
        return {}
    end

    if table_in_size > 32 then
        error("table_in larger than 32 bytes")
        return {}
    end

    -- 32 bytes
    local page = {
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    }
    local page_size = 32

    for i = 1, table_in_size do
        print(i, table_in[table_in_size - i + 1], "goes to", page[32 - i + 1])
        page[32 - i + 1] = table_in[table_in_size - i + 1]
    end
    return page
end

local function eth_call(contract)
    local bytecode_str = redis.call('GET', contract[1]) 
    local bytecode = hexStringToTable(bytecode_str)
    local state = EVM.init(contract[1])
    EVM.execute(state, bytecode)
    local stack_top = state.stack[#state.stack]
    return h(stack_top)
    -- return {state.stack, state.memory, state.storage, state.pc}
end

local function formatHexArray(arr)
    if not arr or #arr == 0 then
        return ""
    end
    local hex_values = {}
    for i = 1, #arr do
        table.insert(hex_values, string.format("%02x", arr[i]))
    end
    return table.concat(hex_values, " ")
end

local function formatStorage(storage)
    if not storage then
        return ""
    end
    local storage_lines = {}
    for key, value in pairs(storage) do
        table.insert(storage_lines, tostring(key) .. ": " .. tostring(value))
    end
    return table.concat(storage_lines, "\\n")
end

local function eth_call_debug(contract)
    local bytecode_str = redis.call('GET', contract[1]) 
    local bytecode = hexStringToTable(bytecode_str)
    local state = EVM.init(contract[1])
    EVM.execute(state, bytecode)
    
    -- Create JSON output
    local json_output = string.format(
        '{"pc": %d, "stack": "%s", "memory": "%s", "storage": "%s"}',
        state.pc,
        formatHexArray(state.stack),
        formatHexArray(state.memory),
        formatStorage(state.storage)
    )
    
    return json_output
end


if redis then
    redis.register_function('eth_call', eth_call)
    redis.register_function('eth_call_debug', eth_call_debug)
end

-- eth_call()
