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
        transient_storage = {},  -- Transient storage for TLOAD/TSTORE
        pc = 1,  -- Program Counter
        logs = {},
        return_data = {},
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

-- Redis key generation and validation helpers for environmental context

-- Generate Redis key for account balance
local function balance_key(address)
    -- Ensure address is properly formatted
    local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
    -- Remove 0x prefix if present and ensure lowercase
    addr_str = addr_str:gsub("^0x", ""):lower()
    return "BALANCE:" .. addr_str
end

-- Generate Redis key for contract code storage
local function code_key(address)
    -- Ensure address is properly formatted
    local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
    -- Remove 0x prefix if present and ensure lowercase
    addr_str = addr_str:gsub("^0x", ""):lower()
    return "CODE:" .. addr_str
end

-- Generate Redis key for contract code hash storage
local function codehash_key(address)
    -- Ensure address is properly formatted
    local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
    -- Remove 0x prefix if present and ensure lowercase
    addr_str = addr_str:gsub("^0x", ""):lower()
    return "CODEHASH:" .. addr_str
end

-- Validate Redis key format for environmental context
local function validate_env_key(key, expected_prefix)
    if not key or type(key) ~= "string" then
        return false
    end
    
    if not key:match("^" .. expected_prefix .. ":") then
        return false
    end
    
    -- Extract address part and validate hex format
    local address_part = key:sub(#expected_prefix + 2)  -- +2 for ":"
    if not address_part:match("^[0-9a-f]+$") then
        return false
    end
    
    return true
end

-- Helper to safely get environmental data from Redis with defaults
local function get_env_data(key, default_value)
    local value = redis.call("GET", key)
    if value == nil or value == false then
        return default_value
    end
    return value
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
    local left_shift = (n * (2^b)) % 0x100000000
    local right_shift = math.floor(n / (2^(32-b)))
    return (left_shift + right_shift) % 0x100000000
end

local function rotlH(h, l, s)
    if s > 32 then
        return bxor64(rotl32(l, s - 32), rotl32(h, s - 32))
    else
        return bxor64(rotl32(h, s), math.floor(l / (2^(32-s))))
    end
end

local function rotlL(h, l, s)
    if s > 32 then
        return bxor64(rotl32(h, s - 32), rotl32(l, s - 32))
    else
        return bxor64(rotl32(l, s), math.floor(h / (2^(32-s))))
    end
end

local function keccakP(s)
    local B = {}
    for i = 1, 10 do B[i] = 0 end
    
    for round = 0, 23 do
        -- Theta
        for x = 0, 4 do
            B[x * 2 + 1] = bxor64(bxor64(bxor64(bxor64(s[x * 2 + 1], s[x * 2 + 11]), s[x * 2 + 21]), s[x * 2 + 31]), s[x * 2 + 41])
            B[x * 2 + 2] = bxor64(bxor64(bxor64(bxor64(s[x * 2 + 2], s[x * 2 + 12]), s[x * 2 + 22]), s[x * 2 + 32]), s[x * 2 + 42])
        end
        
        for x = 0, 4 do
            local idx1 = ((x + 4) % 5) * 2
            local idx0 = ((x + 1) % 5) * 2
            local B0 = B[idx0 + 1]
            local B1 = B[idx0 + 2]
            local Th = bxor64(rotlH(B0, B1, 1), B[idx1 + 1])
            local Tl = bxor64(rotlL(B0, B1, 1), B[idx1 + 2])
            
            for y = 0, 4 do
                s[x * 2 + y * 10 + 1] = bxor64(s[x * 2 + y * 10 + 1], Th)
                s[x * 2 + y * 10 + 2] = bxor64(s[x * 2 + y * 10 + 2], Tl)
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
                local not_b1 = bnot64(B[((x + 1) % 5) * 2 + 1])
                local not_b2 = bnot64(B[((x + 1) % 5) * 2 + 2])
                s[y * 10 + x * 2 + 1] = bxor64(s[y * 10 + x * 2 + 1], band64(not_b1, B[((x + 2) % 5) * 2 + 1]))
                s[y * 10 + x * 2 + 2] = bxor64(s[y * 10 + x * 2 + 2], band64(not_b2, B[((x + 2) % 5) * 2 + 2]))
            end
        end
        
        -- Iota
        s[1] = bxor64(s[1], SHA3_IOTA_H[round + 1])
        s[2] = bxor64(s[2], SHA3_IOTA_L[round + 1])
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
            state[pos + i + 1] = bxor64(state[pos + i + 1], bytes[dataPos + i + 1])
        end
        pos = pos + take
        dataPos = dataPos + take
        
        if pos == blockLen then
            -- Convert to 32-bit words
            for i = 0, 49 do
                local byte_idx = i * 4
                state32[i + 1] = state[byte_idx + 1] + 
                               (state[byte_idx + 2] * 256) +
                               (state[byte_idx + 3] * 65536) +
                               (state[byte_idx + 4] * 16777216)
            end
            
            keccakP(state32)
            
            -- Convert back to bytes
            for i = 0, 49 do
                local word = state32[i + 1]
                local byte_idx = i * 4
                state[byte_idx + 1] = word % 256
                state[byte_idx + 2] = math.floor(word / 256) % 256
                state[byte_idx + 3] = math.floor(word / 65536) % 256
                state[byte_idx + 4] = math.floor(word / 16777216) % 256
            end
            
            pos = 0
        end
    end
    
    -- Padding
    state[pos + 1] = bxor64(state[pos + 1], 0x01)
    state[blockLen] = bxor64(state[blockLen], 0x80)
    
    -- Final permutation
    for i = 0, 49 do
        local byte_idx = i * 4
        state32[i + 1] = state[byte_idx + 1] + 
                       (state[byte_idx + 2] * 256) +
                       (state[byte_idx + 3] * 65536) +
                       (state[byte_idx + 4] * 16777216)
    end
    
    keccakP(state32)
    
    for i = 0, 49 do
        local word = state32[i + 1]
        local byte_idx = i * 4
        state[byte_idx + 1] = word % 256
        state[byte_idx + 2] = math.floor(word / 256) % 256
        state[byte_idx + 3] = math.floor(word / 65536) % 256
        state[byte_idx + 4] = math.floor(word / 16777216) % 256
    end
    
    -- Extract 32 bytes
    local result = "0x"
    for i = 1, 32 do
        result = result .. string.format("%02X", state[i])
    end
    
    return result
end

-- Utility functions for enhanced arithmetic operations

-- Safe stack pop function with underflow protection
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

-- Helper for signed arithmetic operations
local function signed_arithmetic(value)
    -- Convert unsigned 256-bit value to signed
    -- If the high bit is set, it's negative in two's complement
    if value >= 2^255 then
        return value - 2^256
    else
        return value
    end
end

-- Helper for modulo operations with proper zero handling
local function mod_arithmetic(a, b)
    if b == 0 then
        return 0
    end
    local result = a % b
    -- Ensure result is always positive for unsigned operations
    if result < 0 then
        result = result + math.abs(b)
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

    -- SMOD (0x07) - Signed modulo operation
    [0x07] = function(state)
        local a = signed_arithmetic(toNumber(table.remove(state.stack)))
        local b = signed_arithmetic(toNumber(table.remove(state.stack)))
        local result = 0
        if b == 0 then
            result = 0
        else
            result = a % b
            -- Handle sign properly for signed modulo
            if (a < 0) ~= (b < 0) and result ~= 0 then
                result = result + b
            end
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- ADDMOD (0x08) - Addition modulo operation
    [0x08] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        local N = toNumber(table.remove(state.stack))
        local result = 0
        if N == 0 then
            result = 0
        else
            result = (a + b) % N
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- MULMOD (0x09) - Multiplication modulo operation
    [0x09] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        local N = toNumber(table.remove(state.stack))
        local result = 0
        if N == 0 then
            result = 0
        else
            result = (a * b) % N
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

    -- XOR (0x18) - Bitwise exclusive OR
    [0x18] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        table.insert(state.stack, bxor64(a, b))
        state.pc = state.pc + 1
    end,

    -- NOT
    [0x19] = function(state)
        local a = toNumber(table.remove(state.stack))
        table.insert(state.stack, bnot64(a))
        state.pc = state.pc + 1
    end,

    -- BYTE (0x1A) - Extract byte from 32-byte word
    [0x1A] = function(state)
        local i = toNumber(table.remove(state.stack))
        local val = toNumber(table.remove(state.stack))
        
        if i >= 32 then
            table.insert(state.stack, 0)
        else
            -- Extract byte at position i (0 is most significant byte)
            -- Convert to 32-byte representation and extract byte
            local bytes = {}
            local temp_val = val
            
            -- Fill bytes array (little endian)
            for j = 0, 31 do
                bytes[31 - j] = temp_val % 256
                temp_val = math.floor(temp_val / 256)
            end
            
            table.insert(state.stack, bytes[i] or 0)
        end
        state.pc = state.pc + 1
    end,

    -- EXP
    [0x0A] = function(state)
        local a = toNumber(table.remove(state.stack))
        local b = toNumber(table.remove(state.stack))
        local result = 1
        for i = 1, b do
            result = result * a
        end
        table.insert(state.stack, result)
        state.pc = state.pc + 1
    end,

    -- SIGNEXTEND (0x0B) - Sign extension operation
    [0x0B] = function(state)
        local i = toNumber(table.remove(state.stack))
        local x = toNumber(table.remove(state.stack))
        
        if i >= 32 then
            -- If i >= 32, no sign extension needed
            table.insert(state.stack, x)
        else
            -- Sign extend from byte i
            local sign_bit_pos = (i * 8) + 7
            local sign_bit = math.floor(x / (2^sign_bit_pos)) % 2
            
            if sign_bit == 1 then
                -- Negative number - set all higher bits to 1
                local mask = 0
                for bit = sign_bit_pos + 1, 255 do
                    mask = mask + (2^bit)
                end
                x = x + mask
            else
                -- Positive number - clear all higher bits
                local mask = (2^(sign_bit_pos + 1)) - 1
                x = x % (mask + 1)
            end
        end
        
        table.insert(state.stack, x)
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
    end,

    -- ADDRESS
    [0x30] = function(state)
        table.insert(state.stack, state.address)
        state.pc = state.pc + 1
    end,

    -- BALANCE (0x31) - Get account balance
    [0x31] = function(state)
        local address = table.remove(state.stack)
        local balance_key = balance_key(address)
        local balance = get_env_data(balance_key, "0")
        table.insert(state.stack, toNumber(balance))
        state.pc = state.pc + 1
    end,

    -- ORIGIN (0x32) - Get transaction origin address
    [0x32] = function(state)
        local origin = get_env_data("ORIGIN", "0x0000000000000000000000000000000000000000")
        -- Keep as string to preserve full address
        table.insert(state.stack, origin)
        state.pc = state.pc + 1
    end,

    -- CALLER
    [0x33] = function(state)
        local caller = redis.call("GET", "CALLER") or "0x0000000000000000000000000000000000000000"
        table.insert(state.stack, caller)
        state.pc = state.pc + 1
    end,

    -- GASPRICE
    [0x3A] = function(state)
        local gasprice = redis.call("GET", "GASPRICE") or 1000000000
        table.insert(state.stack, toNumber(gasprice))
        state.pc = state.pc + 1
    end,

    -- CALLVALUE
    [0x34] = function(state)
        local value = redis.call("GET", "CALLVALUE") or 0
        table.insert(state.stack, toNumber(value))
        state.pc = state.pc + 1
    end,

    -- CALLDATALOAD
    [0x35] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local calldata = redis.call("GET", "CALLDATA") or ""
        local data_bytes = hexStringToTable(calldata)
        local value = 0
        for i = 0, 31 do
            local byte_val = data_bytes[offset + i + 1] or 0
            value = value + (byte_val * (256 ^ (31 - i)))
        end
        table.insert(state.stack, value)
        state.pc = state.pc + 1
    end,

    -- CALLDATASIZE
    [0x36] = function(state)
        local calldata = redis.call("GET", "CALLDATA") or ""
        local size = math.floor(#calldata / 2)
        table.insert(state.stack, size)
        state.pc = state.pc + 1
    end,

    -- CALLDATACOPY (0x37) - Copy calldata to memory
    [0x37] = function(state)
        local dest_offset = toNumber(table.remove(state.stack))
        local data_offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        
        -- Get calldata from Redis
        local calldata = redis.call("GET", "CALLDATA") or ""
        local data_bytes = hexStringToTable(calldata)
        
        -- Copy bytes from calldata to memory with bounds checking
        -- (Memory expansion is automatic in Lua tables)
        for i = 0, length - 1 do
            local calldata_index = data_offset + i + 1  -- +1 for Lua 1-based indexing
            local memory_index = dest_offset + i        -- 0-based memory indexing
            
            -- If we're reading beyond calldata bounds, pad with zeros
            if calldata_index <= #data_bytes then
                state.memory[memory_index] = data_bytes[calldata_index]
            else
                state.memory[memory_index] = 0
            end
        end
        
        state.pc = state.pc + 1
    end,

    -- CODESIZE (0x38) - Get executing contract code size
    [0x38] = function(state)
        -- Get the current contract's code from Redis (stored under the contract address)
        local code = redis.call("GET", state.address) or ""
        
        -- Calculate code size in bytes (hex string length / 2)
        local code_size = 0
        if code and code ~= "" then
            -- Remove 0x prefix if present and remove spaces
            local hex_code = code:gsub("^0x", ""):gsub("%s+", "")
            code_size = math.floor(#hex_code / 2)
        end
        
        table.insert(state.stack, code_size)
        state.pc = state.pc + 1
    end,

    -- CODECOPY
    [0x39] = function(state)
        local dest_offset = toNumber(table.remove(state.stack))
        local code_offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        local code = redis.call("GET", state.address) or ""
        local code_bytes = hexStringToTable(code)
        for i = 0, length - 1 do
            state.memory[dest_offset + i] = code_bytes[code_offset + i + 1] or 0
        end
        state.pc = state.pc + 1
    end,

    -- BLOCKHASH
    [0x40] = function(state)
        local block_number = toNumber(table.remove(state.stack))
        local blockhash = redis.call("GET", "BLOCKHASH") or "0x0000000000000000000000000000000000000000000000000000000000000000"
        table.insert(state.stack, blockhash)
        state.pc = state.pc + 1
    end,

    -- COINBASE (0x41) - Get block coinbase address
    [0x41] = function(state)
        local coinbase = get_env_data("COINBASE", "0x0000000000000000000000000000000000000000")
        table.insert(state.stack, coinbase)
        state.pc = state.pc + 1
    end,

    -- TIMESTAMP
    [0x42] = function(state)
        local timestamp = redis.call("GET", "TIMESTAMP") or 0
        table.insert(state.stack, toNumber(timestamp))
        state.pc = state.pc + 1
    end,

    -- NUMBER
    [0x43] = function(state)
        local block_number = redis.call("GET", "NUMBER") or 0
        table.insert(state.stack, toNumber(block_number))
        state.pc = state.pc + 1
    end,

    -- PREVRANDAO (0x44) - Get previous block randomness
    [0x44] = function(state)
        local prevrandao = get_env_data("PREVRANDAO", "0x0000000000000000000000000000000000000000000000000000000000000000")
        table.insert(state.stack, prevrandao)
        state.pc = state.pc + 1
    end,

    -- GASLIMIT (0x45) - Get block gas limit
    [0x45] = function(state)
        local gaslimit = get_env_data("GASLIMIT", "30000000")  -- Default 30M gas limit
        table.insert(state.stack, toNumber(gaslimit))
        state.pc = state.pc + 1
    end,

    -- CHAINID
    [0x46] = function(state)
        local chainid = redis.call("GET", "CHAINID") or 1
        table.insert(state.stack, toNumber(chainid))
        state.pc = state.pc + 1
    end,

    -- SELFBALANCE (0x47) - Get current contract balance
    [0x47] = function(state)
        local balance_key = balance_key(state.address)
        local balance = get_env_data(balance_key, "0")
        table.insert(state.stack, toNumber(balance))
        state.pc = state.pc + 1
    end,

    -- BASEFEE (0x48) - Get block base fee
    [0x48] = function(state)
        local basefee = get_env_data("BASEFEE", "1000000000")  -- Default 1 gwei
        table.insert(state.stack, toNumber(basefee))
        state.pc = state.pc + 1
    end,

    -- GAS
    [0x5A] = function(state)
        local gas = redis.call("GET", "GAS") or 21000
        table.insert(state.stack, toNumber(gas))
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
        
        -- Load 32 bytes from memory and construct hex string
        local hex_string = ""
        for i = 0, 31 do
            local byte_val = state.memory[offset + i] or 0
            hex_string = hex_string .. string.format("%02X", byte_val)
        end
        
        -- For small values (up to 7 bytes), convert to number
        -- For larger values, store as hex string to preserve precision
        local leading_zeros = hex_string:match("^(0*)")
        local significant_hex = hex_string:sub(#leading_zeros + 1)
        
        if #significant_hex <= 14 then  -- 7 bytes or less
            local value = tonumber(significant_hex, 16) or 0
            table.insert(state.stack, value)
        else
            -- Store as hex string for large values
            table.insert(state.stack, "0x" .. hex_string)
        end
        
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

    -- SSTORE
    [0x55] = function(state)
        local storage_position = toNumber(table.remove(state.stack))
        local value = toNumber(table.remove(state.stack))
        local hex_position = string.format("%X", storage_position)
        if #hex_position % 2 == 1 then
            hex_position = "0" .. hex_position
        end
        redis.call("SET", state.address .. ":" .. hex_position, string.format("%X", value))
        state.pc = state.pc + 1
    end,

    -- TLOAD (0x5C) - Load from transient storage
    [0x5C] = function(state)
        local storage_position = toNumber(table.remove(state.stack))
        local value = state.transient_storage[storage_position] or 0
        table.insert(state.stack, value)
        state.pc = state.pc + 1
    end,

    -- TSTORE (0x5D) - Store to transient storage
    [0x5D] = function(state)
        local storage_position = toNumber(table.remove(state.stack))
        local value = toNumber(table.remove(state.stack))
        state.transient_storage[storage_position] = value
        state.pc = state.pc + 1
    end,

    -- MCOPY (0x5E) - Memory to memory copy
    [0x5E] = function(state)
        local dest = toNumber(table.remove(state.stack))
        local src = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        
        -- Handle edge case: zero length copy
        if length == 0 then
            state.pc = state.pc + 1
            return
        end
        
        -- Expand memory if necessary for both source and destination
        local max_src = src + length - 1
        local max_dest = dest + length - 1
        local required_size = math.max(max_src, max_dest) + 1
        
        -- Ensure memory is expanded to required size
        while #state.memory < required_size do
            table.insert(state.memory, 0)
        end
        
        -- Perform the copy operation
        -- Handle overlapping regions correctly by copying in the right direction
        if dest <= src then
            -- Copy forward (left to right)
            for i = 0, length - 1 do
                local src_byte = state.memory[src + i] or 0
                state.memory[dest + i] = src_byte
            end
        else
            -- Copy backward (right to left) to handle overlapping regions
            for i = length - 1, 0, -1 do
                local src_byte = state.memory[src + i] or 0
                state.memory[dest + i] = src_byte
            end
        end
        
        state.pc = state.pc + 1
    end,

    -- PC (0x58) - Program counter
    [0x58] = function(state)
        -- Return current program counter (subtract 1 because it will be incremented)
        table.insert(state.stack, state.pc - 1)
        state.pc = state.pc + 1
    end,

    -- MSIZE (0x59) - Memory size
    [0x59] = function(state)
        -- Return current memory size in bytes (highest accessed position + 1)
        local size = 0
        -- Find the highest index that has been accessed
        for i, _ in pairs(state.memory) do
            if i >= size then
                size = i + 1  -- Size is highest index + 1
            end
        end
        table.insert(state.stack, size)
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

    -- SHL (0x1B) - Left bit shift
    [0x1B] = function(state)
        local shift = toNumber(table.remove(state.stack))
        local value = toNumber(table.remove(state.stack))
        
        if shift >= 256 then
            table.insert(state.stack, 0)
        else
            local result = value * (2 ^ shift)
            table.insert(state.stack, result)
        end
        state.pc = state.pc + 1
    end,

    -- SHR
    [0x1C] = function(state)
        local value = toNumber(table.remove(state.stack))
        local shift = toNumber(table.remove(state.stack))
        table.insert(state.stack, math.floor(value / (2 ^ shift)))
        state.pc = state.pc + 1
    end,

    -- SAR (0x1D) - Arithmetic right shift with sign preservation
    [0x1D] = function(state)
        local shift = toNumber(table.remove(state.stack))
        local value = toNumber(table.remove(state.stack))
        
        if shift >= 256 then
            -- Check if value is negative (high bit set)
            if value >= 2^255 then
                table.insert(state.stack, 2^256 - 1)  -- All 1s for negative
            else
                table.insert(state.stack, 0)   -- All 0s for positive
            end
        else
            local result = math.floor(value / (2 ^ shift))
            table.insert(state.stack, result)
        end
        state.pc = state.pc + 1
    end,

    -- RETURN
    [0xF3] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        state.return_data = {}
        for i = 0, length - 1 do
            state.return_data[i + 1] = state.memory[offset + i] or 0
        end
        state.running = false
    end,

    -- REVERT
    [0xFD] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        state.return_data = {}
        for i = 0, length - 1 do
            state.return_data[i + 1] = state.memory[offset + i] or 0
        end
        state.running = false
        state.reverted = true
    end,

    -- RETURNDATASIZE
    [0x3D] = function(state)
        local size = state.return_data and #state.return_data or 0
        table.insert(state.stack, size)
        state.pc = state.pc + 1
    end,

    -- RETURNDATACOPY
    [0x3E] = function(state)
        local dest_offset = toNumber(table.remove(state.stack))
        local data_offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        if state.return_data then
            for i = 0, length - 1 do
                state.memory[dest_offset + i] = state.return_data[data_offset + i + 1] or 0
            end
        end
        state.pc = state.pc + 1
    end,

    -- EXTCODESIZE (0x3B) - Get external contract code size
    [0x3B] = function(state)
        local address = table.remove(state.stack)
        -- Convert address to string if it's a number
        local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
        
        -- Get contract code from Redis
        local code = redis.call("GET", "CODE:" .. addr_str) or ""
        
        -- Calculate code size in bytes (hex string length / 2)
        local code_size = 0
        if code and code ~= "" then
            -- Remove 0x prefix and spaces
            local hex_code = code:gsub("^0x", ""):gsub(" ", "")
            code_size = math.floor(#hex_code / 2)
        end
        
        table.insert(state.stack, code_size)
        state.pc = state.pc + 1
    end,

    -- EXTCODECOPY (0x3C) - Copy external contract code to memory
    [0x3C] = function(state)
        local address = table.remove(state.stack)
        local dest_offset = toNumber(table.remove(state.stack))
        local code_offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        
        -- Convert address to string if it's a number
        local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
        
        -- Get contract code from Redis
        local code = redis.call("GET", "CODE:" .. addr_str) or ""
        local code_bytes = hexStringToTable(code)
        
        -- Expand memory if necessary
        local required_size = dest_offset + length
        while #state.memory < required_size do
            table.insert(state.memory, 0)
        end
        
        -- Copy code bytes to memory
        for i = 0, length - 1 do
            local byte_val = code_bytes[code_offset + i + 1] or 0
            state.memory[dest_offset + i] = byte_val
        end
        
        state.pc = state.pc + 1
    end,

    -- EXTCODEHASH (0x3F) - Get external contract code hash
    [0x3F] = function(state)
        local address = table.remove(state.stack)
        -- Convert address to string if it's a number
        local addr_str = type(address) == "number" and string.format("0x%040X", address) or tostring(address)
        
        -- Check if we have a cached hash first
        local cached_hash = redis.call("GET", "CODEHASH:" .. addr_str)
        if cached_hash then
            table.insert(state.stack, cached_hash)
        else
            -- Get contract code from Redis
            local code = redis.call("GET", "CODE:" .. addr_str) or ""
            
            if code == "" then
                -- Empty account - return 0
                table.insert(state.stack, 0)
            else
                -- Calculate keccak256 hash of the code
                local code_bytes = hexStringToTable(code)
                local hash = keccak256(code_bytes)
                
                -- Cache the hash for future use
                redis.call("SET", "CODEHASH:" .. addr_str, hash)
                
                table.insert(state.stack, hash)
            end
        end
        
        state.pc = state.pc + 1
    end,

    -- STATICCALL
    [0xFA] = function(state)
        local gas = toNumber(table.remove(state.stack))
        local address = table.remove(state.stack)
        local args_offset = toNumber(table.remove(state.stack))
        local args_length = toNumber(table.remove(state.stack))
        local ret_offset = toNumber(table.remove(state.stack))
        local ret_length = toNumber(table.remove(state.stack))
        -- Simplified: just push success (1) for now
        table.insert(state.stack, 1)
        state.pc = state.pc + 1
    end,

    -- LOG1
    [0xA0] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        local topic1 = table.remove(state.stack)
        local log_data = {}
        for i = 0, length - 1 do
            log_data[i + 1] = state.memory[offset + i] or 0
        end
        state.logs = state.logs or {}
        table.insert(state.logs, {data = log_data, topics = {topic1}})
        state.pc = state.pc + 1
    end,

    -- LOG2
    [0xA1] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        local topic1 = table.remove(state.stack)
        local topic2 = table.remove(state.stack)
        local log_data = {}
        for i = 0, length - 1 do
            log_data[i + 1] = state.memory[offset + i] or 0
        end
        state.logs = state.logs or {}
        table.insert(state.logs, {data = log_data, topics = {topic1, topic2}})
        state.pc = state.pc + 1
    end,

    -- LOG3
    [0xA2] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        local topic1 = table.remove(state.stack)
        local topic2 = table.remove(state.stack)
        local topic3 = table.remove(state.stack)
        local log_data = {}
        for i = 0, length - 1 do
            log_data[i + 1] = state.memory[offset + i] or 0
        end
        state.logs = state.logs or {}
        table.insert(state.logs, {data = log_data, topics = {topic1, topic2, topic3}})
        state.pc = state.pc + 1
    end,

    -- LOG4
    [0xA3] = function(state)
        local offset = toNumber(table.remove(state.stack))
        local length = toNumber(table.remove(state.stack))
        local topic1 = table.remove(state.stack)
        local topic2 = table.remove(state.stack)
        local topic3 = table.remove(state.stack)
        local topic4 = table.remove(state.stack)
        local log_data = {}
        for i = 0, length - 1 do
            log_data[i + 1] = state.memory[offset + i] or 0
        end
        state.logs = state.logs or {}
        table.insert(state.logs, {data = log_data, topics = {topic1, topic2, topic3, topic4}})
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
    
    -- Check if stack_top is a full address (42 chars total: 0x + 40 hex chars)
    if type(stack_top) == "string" and stack_top:match("^0x[0-9A-Fa-f]+$") then
        if #stack_top == 42 then
            return stack_top  -- Return full address without formatting
        end
    end
    return h(stack_top)  -- Use normal formatting for all other values including 32-byte values
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