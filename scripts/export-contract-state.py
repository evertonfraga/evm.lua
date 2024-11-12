import os
import redis
from web3 import Web3

# 
# Example usage:
# CONTRACT_ADDRESS="0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640" python export-contract-state.py 
# 

# Connect to Ethereum node
eth_node_url = os.environ.get('RPC_HTTP_ENDPOINT')
web3 = Web3(Web3.HTTPProvider(eth_node_url))

# Connect to Redis
redis_host = "localhost"
redis_port = 6379
r = redis.Redis(host=redis_host, port=redis_port, decode_responses=True)

contract_address = os.environ.get('CONTRACT_ADDRESS')


def fetch_and_save_code(contract_address, start_block):
    result = web3.provider.make_request("eth_getCode", [contract_address, start_block])
    redis_key = f"{contract_address}:C"
    print(redis_key, result['result'])
    r.set(redis_key, result['result'])

def fetch_and_save_storage(contract_address, start_block):
    block_number = web3.eth.get_block(start_block)
    pointer = "0x00"
    limit = 100
    txindex = 0
    while True:
        storage = web3.provider.make_request("debug_storageRangeAt", [start_block, txindex, contract_address, pointer, limit])
        print('STORAGE:', storage)
        for key, value in storage['result']['storage'].items():
            # Save to Redis
            redis_key = f"{contract_address}:S:{key}"
            print(redis_key, value['value'])
            r.set(redis_key, value['value'])

        if storage['result']['nextKey'] is None:
            break
        pointer = storage['result']['nextKey']

    # Feed a pointer with the respective block number for later use
    r.set(f"{contract_address}:pointer", block_number['number'])

# Example usage
# contract_address = "0x88e6a0c2ddd26feeb64f039a2c41296fcb3f5640" # USDC ETH pair
start_block = "safe"  # Or specific block number

fetch_and_save_code(contract_address, start_block)
fetch_and_save_storage(contract_address, start_block)
