#!/bin/bash

# Function to ensure Redis is running
ensure_redis_running() {
    if ! redis-cli ping > /dev/null 2>&1; then
        echo "Redis server not running. Starting redis-server..."
        redis-server --daemonize yes
        
        # Wait for Redis to start
        echo "Waiting for Redis to start..."
        while ! redis-cli ping > /dev/null 2>&1; do
            sleep 1
        done
        echo "Redis server started successfully."
    else
        echo "Redis server is already running."
    fi
}

# Ensure Redis is running before proceeding
ensure_redis_running

cat ../evm.lua | redis-cli -x FUNCTION LOAD REPLACE

# contract=0xd9145CCE52D386f254917e481eB44e9943F39138
# code={0x61, 0x02, 0xfa, 0x00}


# """
# 0x60026040015f5260206000f3
# PUSH1 0x02
# PUSH1 0x40
# ADD
# PUSH0
# MSTORE
# PUSH1 0x20
# PUSH1 0x00
# RETURN
# """

# """
# 0x601e600c01
# PUSH1 0x1e
# PUSH1 0x0c
# ADD
# """

redis-cli SET 0xd9145CCE52D386f254917e481eB44e9943F39138 "60 00 54 60 01 54 01"
redis-cli SET 0xd9145CCE52D386f254917e481eB44e9943F39138:0x0000000000000000000000000000000000000000000000000000000000000000 0x000000000000000000000000000000000000000000000000000000000000001e
redis-cli SET 0xd9145CCE52D386f254917e481eB44e9943F39138:0x0000000000000000000000000000000000000000000000000000000000000001 0x000000000000000000000000000000000000000000000000000000000000000c

redis-cli SET 0xd9145CCE52D386f254917e481eB44e9943F39139 "60 02 60 fa 01"

redis-cli FCALL eth_call 1 "0xd9145CCE52D386f254917e481eB44e9943F39138"
