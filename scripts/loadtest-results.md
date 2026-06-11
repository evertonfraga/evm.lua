# EVM.lua Load Test Results

Driver: `scripts/loadtest.py` — concurrent `FCALL eth_call` over a mix of
workloads (arith / storage / hashing / loop). Redis 8.8.0, Lua 5.5, single
local Redis instance, Apple Silicon.

## Results

| Run | Clients | Requests | Wall (s) | Throughput (calls/s) | Mean (ms) | p50 (ms) | p95 (ms) | p99 (ms) | Errors |
|-----|---------|----------|----------|----------------------|-----------|----------|----------|----------|--------|
| 1   | 1       | 2000     | 10.99    | 182                  | 5.50      | 0.91     | 19.6     | 20.7     | 0      |
| 2   | 8       | 4000     | 19.94    | 201                  | 39.85     | 36.7     | 96.0     | 111.9    | 0      |
| 3   | 32      | 8000     | 37.91    | 211                  | 151.12    | 136.0    | 210.6    | 218.9    | 0      |

## Interpretation

Throughput is essentially **flat (~200 calls/sec) regardless of concurrency**,
while latency grows roughly linearly with client count (mean 5 ms → 40 ms →
151 ms). This is the classic signature of a **single-threaded, blocking
bottleneck**: Redis executes Function/script calls serially on the main thread,
so additional concurrent clients do not increase throughput — they just queue,
inflating tail latency.

The ~200 calls/sec ceiling is dominated by interpreter cost inside `eth_call`
(pure-Lua big-integer emulation and pure-Lua keccak), not by network or Redis
I/O. The p50 in the 1-client run (0.91 ms) shows most calls are fast; the long
tail comes from the hashing workload.

This is the primary motivation for the non-blocking, multi-threaded redesign —
see `docs/SCALING.md`.
