#!/bin/bash

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

# Client-side timeout (seconds) for any redis-cli call. Protects the dev loop:
# a runaway contract (infinite loop / huge KECCAK256) blocks single-threaded
# Redis, and without this the test process would hang indefinitely. Gas metering
# (8M default cap) bounds most runaways server-side; this is the client backstop.
REDIS_TIMEOUT="${REDIS_TIMEOUT:-10}"

# Ensure Redis is running
ensure_redis_running() {
    if ! redis-cli -t "$REDIS_TIMEOUT" ping > /dev/null 2>&1; then
        echo "Redis server not running. Starting redis-server..."
        redis-server --daemonize yes

        # Wait for Redis to start
        echo "Waiting for Redis to start..."
        while ! redis-cli -t "$REDIS_TIMEOUT" ping > /dev/null 2>&1; do
            sleep 1
        done
        echo "Redis server started successfully."
    else
        echo "Redis server is already running."
    fi

    # Return BUSY quickly (1s) instead of the 5s default so a stuck script is
    # detected and recovered fast during the dev loop.
    redis-cli -t "$REDIS_TIMEOUT" CONFIG SET busy-reply-threshold 1000 > /dev/null 2>&1
}

# Force-restart Redis after a runaway script left it BUSY, then reload the
# function. Only SHUTDOWN works once a script has performed a write.
recover_redis() {
    echo "Redis appears stuck; restarting and reloading evm.lua..."
    redis-cli SHUTDOWN NOSAVE > /dev/null 2>&1
    sleep 2
    redis-server --daemonize yes > /dev/null 2>&1
    sleep 1
    load_evm_function > /dev/null 2>&1
}

# True if Redis is blocked running a long script.
redis_is_busy() {
    local out
    out=$(redis-cli -t "$REDIS_TIMEOUT" ping 2>&1)
    [[ "$out" == *BUSY* || "$out" != "PONG" ]]
}

# Bounded EVM call: invoke eth_call with a client timeout, and self-heal if a
# runaway leaves Redis BUSY. Usage: evm_call <address> [extra FCALL args...]
evm_call() {
    local addr="$1"; shift
    local result
    result=$(redis-cli -t "$REDIS_TIMEOUT" FCALL eth_call 1 "$addr" "$@" 2>&1)
    if [[ "$result" == *BUSY* ]] || redis_is_busy; then
        recover_redis
        echo "ERROR: call timed out / Redis recovered"
        return 1
    fi
    echo "$result"
}

# Load EVM function
load_evm_function() {
    cat ../evm.lua | redis-cli -t "$REDIS_TIMEOUT" -x FUNCTION LOAD REPLACE
}

# Setup Redis for testing
setup_redis() {
    ensure_redis_running
    load_evm_function
}
