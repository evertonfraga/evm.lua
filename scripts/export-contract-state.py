import requests
import time
import json

# Ethereum node URL
ETH_NODE_URL = "http://localhost:8545"

NUM_REQUESTS = 0

BLOCKHASH = "0x95b198e154acbfc64109dfd22d8224fe927fd8dfdedfae01587674482ba4baf3" # 18,000,000

def storageRangeAt(blockhash, address, keystart="0x0000000000000000000000000000000000000000000000000000000000000000"):
    DATA = {
        "jsonrpc":"2.0",
        "id":1,
        "method":"debug_storageRangeAt",
        "params":[
            "0xe6a53e859dd14060f41d5ad3d4b9354808689761f4669524fad64f61fea3c18e",
            0,
            address,
            keystart,
            1000
        ]
    }
    response = requests.post(ETH_NODE_URL, json=DATA)



# Start time (in milliseconds)
start_time = time.time()

next_key = False
while next_key:
    storageRangeAt

# End time (in milliseconds)
end_time = time.time()

# Calculate total runtime
runtime_ms = (end_time - start_time) * 1000  # Convert to milliseconds

print(f"Total Runtime: {runtime_ms} milliseconds")
print(f"{NUM_REQUESTS / runtime_ms}")