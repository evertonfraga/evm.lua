import os
import redis
from web3 import Web3

# Connect to Ethereum node
eth_node_url = os.environ.get('RPC_HTTP_ENDPOINT')
web3 = Web3(Web3.HTTPProvider(eth_node_url))

# Connect to Redis
redis_host = "localhost"
redis_port = 6379
r = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

def fetch_and_cache_storage(contract_address, start_block):
    pointer = None
    while True:
        storage = web3.provider.make_request("debug_getStorageRangeAt", [contract_address, start_block, pointer, None])
        for key, value in storage['result']['storage'].items():
            # Save to Redis
            redis_key = f"{contract_address}:S:{key}"
            r.set(redis_key, value['value'])

        if storage['result']['nextKey'] is None:
            break
        pointer = storage['result']['nextKey']

    # Feed a pointer with the respective block number for later use
    r.set(f"{contract_address}:pointer", start_block)

# Example usage
contract_address = "0xYourContractAddressHere"
start_block = "latest"  # Or specific block number
fetch_and_cache_storage(contract_address, start_block)
