#!/usr/bin/env python3
"""
VMTests runner for EVM.lua.

Consumes the official Ethereum Foundation VMTests fixtures from the
`ethereum-tests` submodule and executes each one against the EVM.lua
implementation loaded into Redis as a function library.

A VMTest is structured as:
  - pre:   account state (code, storage, balance, nonce) before execution
  - env:   block-level context (coinbase, number, timestamp, ...)
  - exec:  the call to make (address, code, data, value, caller, ...)
  - post:  expected account state after successful execution
  - gas:   expected remaining gas (ignored here; no gas metering yet)

We set up `pre` + `env` + `exec` in Redis using the *exact* key conventions
that evm.lua reads/writes, invoke `eth_call`, then assert the resulting
storage matches `post`. Tests with no `post` block are "must-not-complete"
tests (the EVM should fail/revert); we treat a raised error as the pass.

Usage:
  python3 vmtest-runner.py [--dir SUBDIR] [--limit N] [--verbose] [--quiet]
"""

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VMTESTS_ROOT = REPO_ROOT / "ethereum-tests" / "LegacyTests" / "Constantinople" / "VMTests"
EVM_LUA = REPO_ROOT / "evm.lua"

# Map VMTest env field -> the Redis key evm.lua reads.
ENV_KEYS = {
    "currentCoinbase": "COINBASE",
    "currentNumber": "NUMBER",
    "currentTimestamp": "TIMESTAMP",
    "currentGasLimit": "GASLIMIT",
    "currentDifficulty": "PREVRANDAO",  # post-merge PREVRANDAO occupies DIFFICULTY slot
}


def redis_cli(*args):
    """Run a redis-cli command and return trimmed stdout."""
    result = subprocess.run(
        ["redis-cli", *[str(a) for a in args]],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


def load_evm_function():
    """Load (or replace) the EVM.lua function library in Redis."""
    with open(EVM_LUA) as f:
        proc = subprocess.run(
            ["redis-cli", "-x", "FUNCTION", "LOAD", "REPLACE"],
            input=f.read(),
            capture_output=True,
            text=True,
        )
    if proc.returncode != 0 or "EVM" not in proc.stdout:
        raise RuntimeError(f"Failed to load evm.lua: {proc.stdout} {proc.stderr}")


def redis_busy():
    """True if Redis is blocked running a long script (a runaway fixture)."""
    out = redis_cli("ping")
    return "BUSY" in out.upper() or out.strip() != "PONG"


def recover_redis():
    """Force-restart Redis after a runaway script and reload the function.

    A single expensive opcode (e.g. a large KECCAK256) can exceed even the step
    budget's wall-time and leave Redis BUSY, where only SHUTDOWN/FUNCTION KILL
    work. Restarting is the reliable way to keep a long fixture sweep going.
    """
    subprocess.run(["redis-cli", "SHUTDOWN", "NOSAVE"], capture_output=True)
    time.sleep(1.5)
    subprocess.run(["redis-server", "--daemonize", "yes", "--save", ""],
                   capture_output=True)
    time.sleep(1.0)
    load_evm_function()


def to_int(hexstr):
    """Parse a 0x-prefixed (or bare) hex string into an int."""
    if hexstr is None:
        return 0
    s = str(hexstr).strip()
    if s.startswith("0x") or s.startswith("0X"):
        return int(s, 16) if s[2:] else 0
    try:
        return int(s, 16)
    except ValueError:
        return int(s)


def storage_pos_key(address, position_hex):
    """Reproduce evm.lua's storage key: address .. ':' .. uppercase-even-hex(pos)."""
    pos = to_int(position_hex)
    h = format(pos, "X")
    if len(h) % 2 == 1:
        h = "0" + h
    return f"{address}:{h}"


def setup_pre(pre):
    """Load pre-state accounts into Redis using evm.lua's key conventions."""
    for address, account in pre.items():
        addr = address if address.startswith("0x") else f"0x{address}"

        code = account.get("code", "0x")
        if code and code != "0x":
            # evm.lua's eth_call reads code directly from the address key.
            redis_cli("SET", addr, code)
            redis_cli("SET", f"CODE:{addr[2:].lower()}", code)

        for pos, value in account.get("storage", {}).items():
            # evm.lua stores storage values as uppercase hex (no 0x prefix).
            redis_cli("SET", storage_pos_key(addr, pos), format(to_int(value), "X"))

        balance = account.get("balance", "0x0")
        redis_cli("SET", f"BALANCE:{addr[2:].lower()}", str(to_int(balance)))


def setup_env(env):
    for field, redis_key in ENV_KEYS.items():
        if field in env:
            redis_cli("SET", redis_key, str(to_int(env[field])))


def setup_exec(ex):
    """Wire up the exec context (caller, value, calldata, origin, ...)."""
    redis_cli("SET", "CALLER", ex.get("caller", "0x0"))
    redis_cli("SET", "ORIGIN", ex.get("origin", "0x0"))
    redis_cli("SET", "CALLVALUE", str(to_int(ex.get("value", "0x0"))))
    redis_cli("SET", "CALLDATA", ex.get("data", "0x"))
    redis_cli("SET", "GASPRICE", str(to_int(ex.get("gasPrice", "0x0"))))
    redis_cli("SET", "GAS", str(to_int(ex.get("gas", "0x0"))))


def check_post(post):
    """Compare on-chain storage against the expected post-state.

    Returns (ok, list_of_mismatch_strings).
    """
    mismatches = []
    for address, account in post.items():
        addr = address if address.startswith("0x") else f"0x{address}"
        for pos, expected in account.get("storage", {}).items():
            actual_raw = redis_cli("GET", storage_pos_key(addr, pos))
            actual = to_int(actual_raw) if actual_raw else 0
            if actual != to_int(expected):
                mismatches.append(
                    f"{addr} slot {pos}: expected {to_int(expected):#x}, got {actual:#x}"
                )
    return (len(mismatches) == 0, mismatches)


def run_one(test):
    """Run a single VMTest case. Returns (status, detail).

    status in {"pass", "fail", "skip"}.
    """
    ex = test.get("exec")
    if not ex:
        return ("skip", "no exec block")

    address = ex["address"]
    addr = address if address.startswith("0x") else f"0x{address}"

    setup_pre(test.get("pre", {}))
    setup_env(test.get("env", {}))
    setup_exec(ex)

    # Ensure the executing code is present at the address key (exec.code wins).
    redis_cli("SET", addr, ex["code"])

    # Guard against runaway scripts: evm.lua has no gas metering, so a fixture
    # with a huge memory/SHA3 length can block single-threaded Redis indefinitely.
    # `-t` bounds the client wait; on timeout we treat it as a failure (and the
    # caller flushes between tests). See the runner README for the broader caveat.
    proc = subprocess.run(
        ["redis-cli", "-t", "5", "FCALL", "eth_call", "1", addr],
        capture_output=True,
        text=True,
    )
    out = proc.stdout.strip()
    errored = (
        proc.returncode != 0
        or out.upper().startswith("ERROR")
        or "BUSY" in out.upper()
    )

    # No `post` block => the test expects execution to fail (invalid opcode,
    # stack underflow, etc.). A raised error is the expected outcome.
    if "post" not in test:
        if errored:
            return ("pass", "expected-failure observed")
        return ("fail", "expected failure but execution completed")

    if errored:
        return ("fail", f"unexpected execution error: {proc.stdout.strip()}")

    ok, mismatches = check_post(test["post"])
    if ok:
        return ("pass", "")
    return ("fail", "; ".join(mismatches[:3]))


def discover(subdir=None):
    root = VMTESTS_ROOT / subdir if subdir else VMTESTS_ROOT
    return sorted(root.rglob("*.json"))


def main():
    ap = argparse.ArgumentParser(description="Run Ethereum VMTests against EVM.lua")
    ap.add_argument("--dir", help="subdirectory under VMTests to run (e.g. vmArithmeticTest)")
    ap.add_argument("--limit", type=int, help="max number of test files to run")
    ap.add_argument("--verbose", action="store_true", help="print every result")
    ap.add_argument("--quiet", action="store_true", help="only print the summary line")
    args = ap.parse_args()

    if not VMTESTS_ROOT.exists():
        print(f"VMTests not found at {VMTESTS_ROOT}", file=sys.stderr)
        print("Run: git submodule update --init --recursive", file=sys.stderr)
        sys.exit(2)

    if subprocess.run(["redis-cli", "ping"], capture_output=True).returncode != 0:
        print("Redis is not running. Start it with `redis-server --daemonize yes`.", file=sys.stderr)
        sys.exit(2)

    load_evm_function()

    files = discover(args.dir)
    if args.limit:
        files = files[: args.limit]

    counts = {"pass": 0, "fail": 0, "skip": 0}
    failures = []

    for path in files:
        try:
            doc = json.load(open(path))
        except (json.JSONDecodeError, OSError) as e:
            counts["skip"] += 1
            continue

        for name, test in doc.items():
            redis_cli("FLUSHDB")
            try:
                status, detail = run_one(test)
            except Exception as e:  # noqa: BLE001 - runner must be resilient
                status, detail = "fail", f"runner exception: {e}"
            counts[status] += 1
            if status == "fail":
                failures.append((f"{path.parent.name}/{path.stem}::{name}", detail))
            if args.verbose and not args.quiet:
                mark = {"pass": "PASS", "fail": "FAIL", "skip": "SKIP"}[status]
                print(f"[{mark}] {path.parent.name}/{name} {detail}")

            # A runaway fixture can leave Redis BUSY (only SHUTDOWN works then);
            # restart it so the rest of the sweep can proceed.
            if redis_busy():
                if not args.quiet:
                    print(f"  ! Redis stuck after {path.stem}/{name}; restarting")
                recover_redis()

    total = sum(counts.values())
    ran = counts["pass"] + counts["fail"]
    pct = (counts["pass"] / ran * 100) if ran else 0.0

    if not args.quiet and failures:
        print("\n--- Failures (first 25) ---")
        for name, detail in failures[:25]:
            print(f"  {name}: {detail}")

    print(
        f"\nVMTests summary: {counts['pass']}/{ran} passed "
        f"({pct:.1f}%), {counts['skip']} skipped, {total} total cases"
    )
    sys.exit(0 if counts["fail"] == 0 else 1)


if __name__ == "__main__":
    main()
