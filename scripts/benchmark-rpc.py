import requests
import time
import json

# Ethereum node URL
ETH_NODE_URL = "http://localhost:8545"

# Example data for the eth_call
# Update these parameters according to your specific contract and method
DATA = {
    "jsonrpc": "2.0",
    "method": "eth_call",
    "params": [{
        "to": "0x0000000000000000000000000000000000000000",
        "data": "0x601e600c01",
        "code": "0x601e600c01"
    }, "latest"],
    "id": 1
}

# Number of requests to send
NUM_REQUESTS = 10000

# Start time (in milliseconds)
start_time = time.time()

# Send eth_call requests
for _ in range(NUM_REQUESTS):
    response = requests.post(ETH_NODE_URL, json=DATA)
    # Optional: Check response here

# End time (in milliseconds)
end_time = time.time()

# Calculate total runtime
runtime_ms = (end_time - start_time) * 1000  # Convert to milliseconds

print(f"Total Runtime: {runtime_ms} milliseconds")
print(f"{NUM_REQUESTS / runtime_ms}")