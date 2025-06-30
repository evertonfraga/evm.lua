#!lua name=EVM

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
    }
    return evmState
end

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

-- Helper function to convert stack values to numbers
local function toNumber(val)
    if type(val) == "number" then
        return val
    elseif type(val) == "string" and val:match("^0x[0-9A-Fa-f]+$") then
        local hex_part = val:sub(3)
        if #hex_part <= 14 then
            return tonumber(val, 16) or 0
        else
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
        if n:match("^0x[0-9A-Fa-f]+$") then
            local hex_part = n:sub(3):upper()
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

-- 64-bit arithmetic using 32-bit chunks for better precision
local function split64(n)
    local high = math.floor(n / 4294967296) % 4294967296
    local low = n % 4294967296
    return high, low
end

local function join64(high, low)
    return (high * 4294967296 + low) % (2^53)
end

local function band64(a, b)
    local ah, al = split64(a)
    local bh, bl = split64(b)
    
    local function band32(x, y)
        local result = 0
        local bit = 1
        for i = 1, 32 do
            if (math.floor(x / bit) % 2 == 1) and (math.floor(y / bit) % 2 == 1) then
                result = result + bit
            end
            bit = bit * 2
            if bit > x and bit > y then break end
        end
        return result
    end
    
    return join64(band32(ah, bh), band32(al, bl))
end

local function bxor64(a, b)
    local ah, al = split64(a)
    local bh, bl = split64(b)
    
    local function bxor32(x, y)
        local result = 0
        local bit = 1
        for i = 1, 32 do
            if (math.floor(x / bit) % 2) ~= (math.floor(y / bit) % 2) then
                result = result + bit
            end
            bit = bit * 2
            if bit > x and bit > y then break end
        end
        return result
    end
    
    return join64(bxor32(ah, bh), bxor32(al, bl))
end

local function bnot64(a)
    return bxor64(a, 0x1FFFFFFFFFFFFF)
end

local function lrotate64(value, amount)
    if amount == 0 then return value end
    amount = amount % 64
    
    local high, low = split64(value)
    
    if amount == 32 then
        return join64(low, high)
    elseif amount < 32 then
        local new_high = ((high * (2^amount)) % 4294967296) + math.floor(low / (2^(32-amount)))
        local new_low = ((low * (2^amount)) % 4294967296) + math.floor(high / (2^(32-amount)))
        return join64(new_high % 4294967296, new_low % 4294967296)
    else
        amount = amount - 32
        local new_high = ((low * (2^amount)) % 4294967296) + math.floor(high / (2^(32-amount)))
        local new_low = ((high * (2^amount)) % 4294967296) + math.floor(low / (2^(32-amount)))
        return join64(new_high % 4294967296, new_low % 4294967296)
    end
end

-- Keccak implamentation ported from: https://github.com/paulmillr/noble-hashes/
-- Keccak256 constants
local SHA3_PI = {2,6,12,18,24,3,9,10,16,22,1,7,13,19,20,4,5,11,17,23,8,14,15,21,2}
local SHA3_ROTL = {1,3,6,10,15,21,28,36,45,55,2,14,27,41,56,8,25,43,62,18,39,61,20,44}
local SHA3_IOTA_H = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local SHA3_IOTA_L = {1,130,32898,32906,2147516416,2147483649,32777,138,136,2147516425,2147483658,2147516555,139,32905,32771,32770,128,32778,2147483658,2147516545,32896,2147483649,2147516424,2147516555}

local function rotl32(n, b)
    n = n % 0x100000000
    return ((n << b) | (n >> (32 - b))) % 0x100000000
end

local function rotlH(h, l, s)
    if s > 32 then
        return rotl32(l, s - 32) ~ rotl32(h, s - 32)
    else
        return rotl32(h, s) ~ (l >> (32 - s))
    end
end

local function rotlL(h, l, s)
    if s > 32 then
        return rotl32(h, s - 32) ~ rotl32(l, s - 32)
    else
        return rotl32(l, s) ~ (h >> (32 - s))
    end
end

local function keccakP(s)
    local B = {}
    for i = 1, 10 do B[i] = 0 end
    
    for round = 0, 23 do
        -- Theta
        for x = 0, 4 do
            B[x * 2 + 1] = s[x * 2 + 1] ~ s[x * 2 + 11] ~ s[x * 2 + 21] ~ s[x * 2 + 31] ~ s[x * 2 + 41]
            B[x * 2 + 2] = s[x * 2 + 2] ~ s[x * 2 + 12] ~ s[x * 2 + 22] ~ s[x * 2 + 32] ~ s[x * 2 + 42]
        end
        
        for x = 0, 4 do
            local idx1 = ((x + 4) % 5) * 2
            local idx0 = ((x + 1) % 5) * 2
            local B0 = B[idx0 + 1]
            local B1 = B[idx0 + 2]
            local Th = rotlH(B0, B1, 1) ~ B[idx1 + 1]
            local Tl = rotlL(B0, B1, 1) ~ B[idx1 + 2]
            
            for y = 0, 4 do
                s[x * 2 + y * 10 + 1] = s[x * 2 + y * 10 + 1] ~ Th
                s[x * 2 + y * 10 + 2] = s[x * 2 + y * 10 + 2] ~ Tl
            end
        end
        
        -- Rho and Pi
        local curH = s[3]
        local curL = s[4]
        
        for t = 0, 23 do
            local shift = SHA3_ROTL[t + 1]
            local Th = rotlH(curH, curL, shift)
            local Tl = rotlL(curH, curL, shift)
            local PI = SHA3_PI[t + 1]
            curH = s[PI + 1]
            curL = s[PI + 2]
            s[PI + 1] = Th
            s[PI + 2] = Tl
        end
        
        -- Chi
        for y = 0, 4 do
            for x = 0, 4 do
                B[x * 2 + 1] = s[y * 10 + x * 2 + 1]
                B[x * 2 + 2] = s[y * 10 + x * 2 + 2]
            end
            for x = 0, 4 do
                s[y * 10 + x * 2 + 1] = s[y * 10 + x * 2 + 1] ~ ((~B[((x + 1) % 5) * 2 + 1]) & B[((x + 2) % 5) * 2 + 1])
                s[y * 10 + x * 2 + 2] = s[y * 10 + x * 2 + 2] ~ ((~B[((x + 1) % 5) * 2 + 2]) & B[((x + 2) % 5) * 2 + 2])
            end
        end
        
        -- Iota
        s[1] = s[1] ~ SHA3_IOTA_H[round + 1]
        s[2] = s[2] ~ SHA3_IOTA_L[round + 1]
    end
end

local function keccak256(data)
    local state32 = {}
    for i = 1, 50 do state32[i] = 0 end
    
    local state = {}
    for i = 1, 200 do state[i] = 0 end
    
    local blockLen = 136
    local pos = 0
    
    -- Absorb
    local bytes = type(data) == "string" and {data:byte(1, #data)} or data
    local len = #bytes
    local dataPos = 0
    
    while dataPos < len do
        local take = math.min(blockLen - pos, len - dataPos)
        for i = 0, take - 1 do
            state[pos + i + 1] = state[pos + i + 1] ~ bytes[dataPos + i + 1]
        end
        pos = pos + take
        dataPos = dataPos + take
        
        if pos == blockLen then
            -- Convert to 32-bit words
            for i = 0, 49 do
                local byte_idx = i * 4
                state32[i + 1] = state[byte_idx + 1] | 
                               (state[byte_idx + 2] << 8) |
                               (state[byte_idx + 3] << 16) |
                               (state[byte_idx + 4] << 24)
            end
            
            keccakP(state32)
            
            -- Convert back to bytes
            for i = 0, 49 do
                local word = state32[i + 1]
                local byte_idx = i * 4
                state[byte_idx + 1] = word & 0xFF
                state[byte_idx + 2] = (word >> 8) & 0xFF
                state[byte_idx + 3] = (word >> 16) & 0xFF
                state[byte_idx + 4] = (word >> 24) & 0xFF
            end
            
            pos = 0
        end
    end
    
    -- Padding
    state[pos + 1] = state[pos + 1] ~ 0x01
    state[blockLen] = state[blockLen] ~ 0x80
    
    -- Final permutation
    for i = 0, 49 do
        local byte_idx = i * 4
        state32[i + 1] = state[byte_idx + 1] | 
                       (state[byte_idx + 2] << 8) |
                       (state[byte_idx + 3] << 16) |
                       (state[byte_idx + 4] << 24)
    end
    
    keccakP(state32)
    
    for i = 0, 49 do
        local word = state32[i + 1]
        local byte_idx = i * 4
        state[byte_idx + 1] = word & 0xFF
        state[byte_idx + 2] = (word >> 8) & 0xFF
        state[byte_idx + 3] = (word >> 16) & 0xFF
        state[byte_idx + 4] = (word >> 24) & 0xFF
    end
    
    -- Extract 32 bytes
    local result = "0x"
    for i = 1, 32 do
        result = result .. string.format("%02X", state[i])
    end
    
    return result
end

-- Define opcodes
EVM.opcodes = {
    -- STOP
    [0x00] = function(state)
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
        table.insert(state.stack, band64(a, b))
        state.pc = state.pc + 1
    end,

    -- OR
    [0x17] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
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
        
        local data = {}
        for i = 1, length do
            data[i] = state.memory[offset + i - 1] or 0
        end
        
        local hash = keccak256(data)
        table.insert(state.stack, hash)
        state.pc = state.pc + 1
    ende.stack))
        
        -- Extract data from memory
        local data = {}
        for i = 1, length do
            data[i] = state.memory[offset + i - 1] or 0
        end
        
        -- Proper Keccak256 implementation
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

local function eth_call(contract)
    local bytecode_str = redis.call('GET', contract[1]) 
    local bytecode = hexStringToTable(bytecode_str)
    local state = EVM.init(contract[1])
    EVM.execute(state, bytecode)
    local stack_top = state.stack[#state.stack]
    return h(stack_top)
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