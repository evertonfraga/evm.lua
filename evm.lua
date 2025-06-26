#!lua name=EVM

-- if _G then
--     print("GLOBAL _TEST FOUND")
-- end

local function print(v)
    -- NOOP, as redis can't print
end

-- Define a local environment for the EVM implementation
local EVM = {}

-- Initialize the necessary components for the EVM
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
    hexString = hexString:gsub("^0x", "")
    hexString = hexString:gsub(" ", "")
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

local function h(n)
    -- print(n)
    if type(n) == "boolean" then
        return n and "true" or "false"
    elseif type(n) == "string" then
        return n
    elseif type(n) == "number" then
        return string.format("0x%02X", n)
    else
        return tostring(n)
    end
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
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        table.insert(state.stack, a + b)
        state.pc = state.pc + 1
    end,

    -- MUL
    [0x02] = function(state)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        table.insert(state.stack, a * b)
        state.pc = state.pc + 1
    end,

    -- SUB
    [0x03] = function(state)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        table.insert(state.stack, a - b)
        state.pc = state.pc + 1
    end,

    -- DIV
    [0x04] = function(state)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
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
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
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

    -- LT
    [0x10] = function(state, bytecode)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        
        if a > b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- GT
    [0x11] = function(state, bytecode)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        
        if a < b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,
    

    -- SLT
    [0x12] = function(state, bytecode)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        
        if a > b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- SGT
    [0x13] = function(state, bytecode)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        
        if a < b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- EQ
    [0x14] = function(state, bytecode)
        local a = table.remove(state.stack)
        local b = table.remove(state.stack)
        
        if a == b then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- ISZERO
    [0x15] = function(state, bytecode)
        local a = table.remove(state.stack)
        
        if a == 0 then
            table.insert(state.stack, 1)
        else
            table.insert(state.stack, 0)
        end

        state.pc = state.pc + 1
    end,

    -- AND
    -- [0x16] = function(state)
    --     local a = table.remove(state.stack)
    --     local b = table.remove(state.stack)
    --     table.insert(state.stack, a & b)
    --     state.pc = state.pc + 1
    -- end,

    -- -- OR
    -- [0x17] = function(state)
    --     local a = table.remove(state.stack)
    --     local b = table.remove(state.stack)
    --     table.insert(state.stack, a | b)
    --     state.pc = state.pc + 1
    -- end,

    -- POP
    [0x50] = function(state, bytecode)
        local a = table.remove(state.stack)
        state.pc = state.pc + 1
    end,

    -- SLOAD
    [0x54] = function(state, bytecode)
        local storage_position = table.remove(state.stack)
        local value = redis.call("GET", state.address .. ":" .. storage_position)
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
        local offset = table.remove(state.stack)

        if bytecode[offset+1] == 0x5B then -- JUMPDEST
            state.pc = offset+1
        else 
            state.running = false
            print("Not a jump destination")
        end
    end,

    -- JUMPI
    [0x57] = function(state, bytecode)
        print("JUMPI")
        local offset = table.remove(state.stack)
        local b = table.remove(state.stack)

        if b == 0 then
            state.pc = state.pc + 1
        else
            print("offset: ", offset)
            -- print("∆∆", offset, h(bytecode[offset+1]))
            
            if bytecode[offset+1] == 0x5B then -- JUMPDEST
                state.pc = offset + 4
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

    -- To-do: extract stack operations (table.insert, table.remove) to a function
    -- To-do: Consider rewriting the stack operations to use a custom counter. e.g: https://www.lua.org/pil/11.4.html
    -- PUSH0
    [0x5F] = function(state, bytecode)
        table.insert(state.stack, 0)
        state.pc = state.pc + 1
    end,

    -- PUSH1..PUSH7 are added dynamically.
    -- 0x60 to 0x66

    -- DUP1..DUP16 are added dynamically.
    -- 0x80..0x8F

    -- SWAP1..SWAP16 are added dynamically.
    -- 0x90..0x9F

    -- example:
    -- -- POP
    -- [0x50] = function(state, bytecode)
    --     local a = table.remove(state.stack)
    --     state.pc = state.pc + 1
    -- end,
}


local function lshift(x, n)
    return x * (2 ^ n)
end

local function rshift(x, n)
    return math.floor(x / (2 ^ n))
end


-- Adds PUSH1 to PUSH7 opcodes
-- TODO: implement PUSH8 til 32. integer overflow
local function pushN(state, bytecode, numBytes)
    local bytes = 0
    state.pc = state.pc + 1
    for i = 1, numBytes do
        bytes = bytes + bytecode[state.pc]
        bytes = lshift(bytes, 8)
        state.pc = state.pc + 1
    end
    bytes = rshift(bytes, 8)
    table.insert(state.stack, bytes)
end
for i = 1, 7 do
    local opcode = 0x5F + i  -- Calculating the opcode (0x60 is PUSH1)
    -- print("==============", h(opcode))
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
    local first = state.stack[count]
    local other = state.stack[count - n]

    state.stack[count] = other
    state.stack[count - n] = first
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
            -- Handle unknown opcode
            print("Unknown opcode: ", opcode)
            state.running = false
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
    return h(state.stack[1])
    -- return {state.stack, state.memory, state.storage, state.pc}
end



local function formatStack(stack)
    if not stack or #stack == 0 then
        return ""
    end
    local hex_values = {}
    for i = 1, #stack do
        -- Convert to hex and pad to 2 digits
        table.insert(hex_values, string.format("%02x", stack[i]))
    end
    return table.concat(hex_values, " ")
end

local function formatMemory(memory)
    if not memory or #memory == 0 then
        return ""
    end
    local hex_values = {}
    for i = 1, #memory do
        -- Convert to hex and pad to 2 digits
        table.insert(hex_values, string.format("%02x", memory[i]))
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
    return table.concat(storage_lines, "\n")
end

local function eth_call_debug(contract)
    local bytecode_str = redis.call('GET', contract[1]) 
    local bytecode = hexStringToTable(bytecode_str)
    local state = EVM.init(contract[1])
    EVM.execute(state, bytecode)
    
    -- Format output according to specified format
    local output = "PC: " .. tostring(state.pc) .. "\n\n"
    output = output .. "Stack\n" .. formatStack(state.stack) .. "\n\n"
    output = output .. "Storage\n" .. formatStorage(state.storage) .. "\n\n"
    output = output .. "Memory\n" .. formatMemory(state.memory)
    
    return output
end



if redis then
    redis.register_function('eth_call', eth_call)
    redis.register_function('eth_call_debug', eth_call_debug)
end

-- eth_call()
