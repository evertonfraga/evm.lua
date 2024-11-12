import os
import redis
from web3 import Web3

# 
# Example usage:
# CONTRACT_ADDRESS="0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640" python export-contract-state-delta.py 
# 

# This script picks up the last block indexed for the address, and indexes the blocks since the last sync, looking for state changes on it.
# It updates the Redis entries for each of the updated keys.

# This can be further optimized by:
# 1. using binary search on the account storage (eth_getProof).
# 2. spot checking storage root for contract for each block


# Connect to Ethereum node
eth_node_url = os.environ.get('RPC_HTTP_ENDPOINT')
web3 = Web3(Web3.HTTPProvider(eth_node_url))

# Connect to Redis
redis_host = "localhost"
redis_port = 6379
r = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

contract_address = os.environ.get('CONTRACT_ADDRESS')
block_from = int(r.get(f"{contract_address}:pointer"))
block_to = web3.eth.get_block('safe')['number']

print('Last block indexed:', block_from)
print('Target block:', block_to)

if block_to <= block_from:
    print("Nothing to do.", block_from, block_to)
    exit(0)

while block_from < block_to:
    block_from = block_from + 1

    # Get state transitions per block
    rpc_diff = web3.provider.make_request("debug_traceBlockByNumber", [int(block_from)+1, {"tracer":"prestateTracer", "tracerConfig":{"diffMode":True}}])

    print(block_from)

    for tx in rpc_diff['result']:
        # look for contract address on POST state
        if contract_address in tx['result']['post']:
            post_state = tx['result']['post'][contract_address]['storage']

            for key, value in post_state.items():
                redis_key = f"{contract_address}:S:{key}"
                print("\t", redis_key, value)
                r.set(redis_key, value)

exit(0)

