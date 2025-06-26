#!/bin/bash

clear

# ANSI color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Convert hex to decimal, removing 0x prefix
hex_to_dec() {
    local hex_val="${1#0x}"  # Remove 0x prefix
    printf "%d" "0x$hex_val"  # Convert to decimal
}

# Success logging function
success() {
    local message="$1"
    echo -e "${GREEN}✓ $message${NC}"
}

# Failure logging function
fail() {
    local message="$1"
    local expected="$2"
    local actual="$3"
    echo -e "${RED}✗ $message${NC}"
    if [ -n "$expected" ] && [ -n "$actual" ]; then
        echo -e "${YELLOW}  Expected: $expected${NC}"
        echo -e "${YELLOW}  Got:      $actual${NC}"
    fi
}

# Ensure Redis is running
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

# Load EVM function
load_evm_function() {
    cat ../evm.lua | redis-cli -x FUNCTION LOAD REPLACE
}
