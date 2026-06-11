#!/usr/bin/env python3
"""
Load test for the EVM.lua Redis function.

Drives `FCALL eth_call` concurrently from a configurable number of worker
threads across a mix of realistic contract workloads, then reports throughput
and latency percentiles.

The workloads are deliberately varied so the numbers reflect end-to-end EVM
interpretation cost, not just Redis round-trips:
  - arith    : tight ADD/MUL sequence ending in SSTORE (compute-bound)
  - storage  : repeated SSTORE/SLOAD (Redis write-bound)
  - hashing  : KECCAK256 over a small buffer (CPU-bound in pure-Lua keccak)
  - loop     : bounded JUMP loop (interpreter-dispatch-bound)

Because Redis Functions execute single-threaded on the server, this load test
measures how the current blocking design behaves under concurrent clients --
the headline finding that motivates the non-blocking redesign.

Usage:
  python3 loadtest.py [--clients N] [--requests R] [--workload all|arith|...]
"""

import argparse
import statistics
import threading
import time
from collections import defaultdict

try:
    import redis
except ImportError:
    raise SystemExit("redis-py is required: python3 -m pip install redis")


# Each workload is (address, runtime-bytecode-hex). All end in STOP/SSTORE so
# they terminate quickly and deterministically.
WORKLOADS = {
    # PUSH1 2, PUSH1 3, ADD, PUSH1 4, MUL, PUSH1 0, SSTORE, STOP  => (2+3)*4=20 -> slot 0
    "arith": ("0xa0000000000000000000000000000000000000a1",
              "6002600301600402600055" + "00"),
    # 8x (PUSH1 v, PUSH1 slot, SSTORE) then SLOAD slot0, STOP
    "storage": ("0xa0000000000000000000000000000000000000a2",
                "".join(f"60{v:02x}60{s:02x}55" for s, v in enumerate(range(1, 9)))
                + "600054" + "00"),
    # store 32 bytes via MSTORE then KECCAK256(0,32), SSTORE result, STOP
    # PUSH1 0xff PUSH1 0 MSTORE PUSH1 0x20 PUSH1 0 SHA3 PUSH1 0 SSTORE STOP
    "hashing": ("0xa0000000000000000000000000000000000000a3",
                "60ff60005260206000206000" + "55" + "00"),
    # bounded loop: counter at slot0 counts down from 16
    # JUMPDEST-based loop exercising interpreter dispatch
    # PUSH1 16 [JUMPDEST(pc2)] PUSH1 1 SWAP1 SUB DUP1 PUSH1 2 JUMPI POP PUSH1 0 SSTORE STOP
    "loop": ("0xa0000000000000000000000000000000000000a4",
             "6010" + "5b" + "6001900380" + "6002" + "57" + "50" + "600055" + "00"),
}


def deploy(client):
    """Install all workload contracts into Redis."""
    for _, (addr, code) in WORKLOADS.items():
        client.set(addr, code)


def worker(host, port, addresses, n, results, idx):
    """Run `n` FCALLs round-robining over `addresses`; record per-call latency ms."""
    client = redis.Redis(host=host, port=port)
    latencies = []
    errors = 0
    for i in range(n):
        addr = addresses[i % len(addresses)]
        t0 = time.perf_counter()
        try:
            client.fcall("eth_call", 1, addr)
        except Exception:  # noqa: BLE001 - count, don't crash the run
            errors += 1
        latencies.append((time.perf_counter() - t0) * 1000.0)
    results[idx] = (latencies, errors)


def pct(sorted_vals, p):
    if not sorted_vals:
        return 0.0
    k = int(round((p / 100.0) * (len(sorted_vals) - 1)))
    return sorted_vals[k]


def run(host, port, clients, requests, workload):
    r = redis.Redis(host=host, port=port)
    r.ping()
    deploy(r)

    if workload == "all":
        addresses = [addr for addr, _ in WORKLOADS.values()]
    else:
        addresses = [WORKLOADS[workload][0]]

    per_client = max(1, requests // clients)
    total = per_client * clients

    results = [None] * clients
    threads = [
        threading.Thread(target=worker,
                         args=(host, port, addresses, per_client, results, i))
        for i in range(clients)
    ]

    start = time.perf_counter()
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    wall = time.perf_counter() - start

    all_lat = []
    errors = 0
    for lat, err in results:
        all_lat.extend(lat)
        errors += err
    all_lat.sort()

    throughput = total / wall if wall > 0 else 0.0

    print(f"  clients={clients}  requests={total}  workload={workload}")
    print(f"  wall time     : {wall:.3f} s")
    print(f"  throughput    : {throughput:,.0f} calls/sec")
    print(f"  errors        : {errors}")
    print(f"  latency mean  : {statistics.mean(all_lat):.3f} ms")
    print(f"  latency p50   : {pct(all_lat, 50):.3f} ms")
    print(f"  latency p95   : {pct(all_lat, 95):.3f} ms")
    print(f"  latency p99   : {pct(all_lat, 99):.3f} ms")
    print(f"  latency max   : {all_lat[-1] if all_lat else 0:.3f} ms")
    return {"throughput": throughput, "p99": pct(all_lat, 99), "errors": errors, "wall": wall}


def main():
    ap = argparse.ArgumentParser(description="Load test EVM.lua via Redis FCALL")
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=6379)
    ap.add_argument("--clients", type=int, default=8, help="concurrent worker threads")
    ap.add_argument("--requests", type=int, default=4000, help="total requests across all clients")
    ap.add_argument("--workload", default="all",
                    choices=["all", *WORKLOADS.keys()])
    args = ap.parse_args()

    print(f"=== EVM.lua load test ===")
    run(args.host, args.port, args.clients, args.requests, args.workload)


if __name__ == "__main__":
    main()
