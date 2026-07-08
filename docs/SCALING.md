# Scaling EVM.lua: Toward a Non-Blocking, Multi-Threaded Implementation

This document records the system-improvement findings from the end-to-end test
and load-test work, and lays out a concrete path toward a non-blocking,
multi-threaded EVM execution layer.

## Where we are today

`evm.lua` is a single Redis Function (`eth_call`) that interprets EVM bytecode
synchronously. State lives directly in Redis keys (code at `<address>`, storage
at `<address>:<slot>`, balances at `BALANCE:<addr>`, block context at `NUMBER`,
`TIMESTAMP`, etc.). A call reads bytecode, runs the interpreter loop, mutates
Redis in place via `SET`/`DEL`/`INCR`, and returns the stack top.

### Measured behavior (see `scripts/loadtest-results.md`)

| Clients | Throughput (calls/s) | Mean latency | p99 latency |
|---------|----------------------|--------------|-------------|
| 1       | 182                  | 5.5 ms       | 20.7 ms     |
| 8       | 201                  | 39.9 ms      | 111.9 ms    |
| 32      | 211                  | 151.1 ms     | 218.9 ms    |

**Throughput is flat (~200 calls/sec) regardless of concurrency; latency grows
linearly with client count.** This is the defining symptom of a single-threaded,
blocking execution model.

## Root-cause findings

### 1. Redis Functions execute serially on the main thread
Redis runs Lua scripts/functions one at a time on the main event-loop thread.
While `eth_call` runs, *all other Redis traffic is blocked* — there is no
intra-server parallelism available to the current design. Concurrent clients
queue, so adding clients cannot raise throughput, only latency.

### 2. No execution bound → DoS risk (found during testing — now fixed)
Several official VMTests fixtures (e.g. `vmSha3Test/sha3_3`,
`vmIOandFlowOperations` loop tests) supply enormous memory/SHA3 lengths or
infinite `JUMP` loops. With no execution bound, a single such call blocked Redis
for **>200 seconds** during testing, requiring `SHUTDOWN NOSAVE` to recover.

**This is now addressed by gas metering** (see recommendation B below, now
implemented): every opcode is charged gas against a single pool shared across the
whole call tree, with a configurable cap (Redis key `GAS_CAP`, default
8,000,000). An infinite loop now halts with "Out of gas" in ~2s instead of
running forever. A `MAX_MEM_BYTES` clamp remains as a secondary hard ceiling on
per-opcode work (pure-Lua keccak is O(n) per byte). On the client side,
`tests/lib.sh` wraps calls with a `redis-cli -t` timeout and a `recover_redis`
restart so the developer loop can never hang on a runaway contract.

### 3. 256-bit arithmetic is emulated with Lua doubles
Lua numbers are IEEE-754 doubles (53-bit mantissa). `toNumber()` truncates large
values to the low 56 bits, so full-width 256-bit results are wrong — this is why
arithmetic VMTests that expect `0xfff...ffe` fail. A correct, scalable EVM needs
real 256-bit integers (see below). This also affects hashing throughput: keccak
is implemented in pure Lua at ~0.14 ms/byte.

### 4. State mutation is in-place and global
Opcodes write directly to shared Redis keys mid-execution. There is no
transaction boundary, no snapshot/rollback, and no isolation between concurrent
executions. `REVERT` does not undo `SSTORE`s already written. This blocks both
correctness (revert semantics) and concurrency (no way to run two calls without
them stepping on each other's state).

## Recommendations

Ordered by leverage. The first three are prerequisites for *any* safe
concurrency; the last three deliver the actual non-blocking, multi-threaded
execution.

### A. Introduce a journaled, copy-on-write state layer (highest priority)
Replace direct `redis.call("SET", ...)` in opcode handlers with an in-memory
`StateDB` object on `state`:
  - reads fall through to Redis on miss, then cache;
  - writes go to a per-call dirty map (the journal), not Redis;
  - `REVERT`/failed `CALL` discards the journal frame;
  - success commits the journal back to Redis atomically at the end.

This fixes revert correctness **and** gives each execution an isolated view —
the foundation for running executions concurrently.

### B. Add gas metering — ✅ IMPLEMENTED
Charge gas per opcode and per memory word. Halt with out-of-gas when exhausted.
This removes the DoS class entirely. Implemented in `evm.lua`:
  - A static `GAS_COSTS` table (Berlin+-aligned tiers for all opcodes, plus
    PUSH/DUP/SWAP ranges).
  - `dynamic_gas()` adds size-dependent cost for KECCAK256, EXP, the COPY family,
    and LOGn (per-word / per-byte / per-topic).
  - A single gas pool (`state.budget`) shared across the entire call tree, so
    nested CALL/CREATE frames draw from one cap rather than multiplying it.
  - Configurable cap via the Redis key **`GAS_CAP`**, defaulting to **8,000,000**.
  - The `GAS` opcode (0x5A) now reports gas *remaining* (real EVM semantics).

Still TODO: quadratic memory-expansion gas and the EIP-2929 warm/cold access
distinction, which would let the giant-length VMTests pass for the right reason
(they expect out-of-gas at a specific gas figure).

### C. Use real 256-bit integers
Two options:
  - **Lua-side bignum**: a `u256` represented as 4×64-bit limbs (or 8×32-bit on
    5.1/5.3). Correct but slow in pure Lua.
  - **Native module / off-Redis executor**: move execution out of the Redis Lua
    sandbox into a host process (Rust/Go/C) that has native 256-bit support and
    real keccak. Strongly preferred for performance — see D.

### D. Move execution off the Redis main thread (the non-blocking core)
Redis Functions cannot be made multi-threaded from inside Lua. To get true
non-blocking, multi-threaded execution, run the interpreter **outside** the Redis
event loop:
  1. **Sidecar executor service** (Rust/Go): a stateless, multi-threaded process
     that pulls work, executes EVM bytecode with native u256 + gas, and uses
     Redis purely as the state store (with the StateDB/journal from A). Scales
     horizontally by adding workers; Redis is no longer the compute bottleneck.
  2. **Redis Functions as a thin dispatcher**: `eth_call` enqueues a job
     (`LPUSH`) and returns a handle; workers `BLPOP`, execute, and write results.
     Clients poll/subscribe. This keeps the Redis API surface while removing
     blocking execution from the main thread.
  3. If execution must stay in-process, use a **module (Valkey/Redis module API)**
     with `RedisModule_ThreadSafeContext` and a worker pool, rather than a Lua
     Function — but native u256/keccak still argue for an external executor.

### E. Optimistic-concurrency commits
With per-call journals (A), let executions run in parallel and commit with a
compare-and-set on touched slots (or a `WATCH`/`MULTI` transaction). On conflict,
re-execute. This gives serializable semantics without a global lock, so
independent contracts scale linearly across workers.

### F. Hot-path performance
  - Replace pure-Lua keccak with a native implementation (biggest single CPU win;
    keccak dominates the load-test tail latency).
  - Precompile/cache the hex→bytecode decode per contract instead of re-decoding
    on every call.
  - Avoid per-opcode Redis round-trips (the StateDB cache in A handles this).

## Suggested sequencing

1. **A + B** (journaled StateDB + gas) — correctness and safety, in-place in Lua.
2. **C** (u256) — correctness for arithmetic/hashing fixtures.
3. **D** (external multi-threaded executor) — the non-blocking scalability win.
4. **E + F** — linear scaling and hot-path speed.

Steps 1–2 raise VMTests pass rates and remove the DoS risk while staying within
the current Redis-Function deployment. Step 3 is the architectural change that
breaks the ~200 calls/sec single-thread ceiling.
