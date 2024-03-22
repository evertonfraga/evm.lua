import redis
import time

# Parameters for Redis connection
# Update these with your Redis server details
REDIS_HOST = 'localhost'
REDIS_PORT = 6379
REDIS_DB = 0

# Define the Redis function SHA1 hash
# Replace <FUNCTION_NAME> with the actual hash of your Redis function
FUNCTION_NAME = "eth_call"

# Number of invocations
NUM_INVOCATIONS = 1000

# Connect to Redis
client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=REDIS_DB)

# Start time (in milliseconds)
start_time = time.time()

# Invoke the Redis function 10,000 times
for _ in range(NUM_INVOCATIONS):
    # client.fcall(FUNCTION_NAME, 1, "0xd9145CCE52D386f254917e481eB44e9943F39138")
    client.fcall(FUNCTION_NAME, 1, "0xd9145CCE52D386f254917e481eB44e9943F39139")

# End time (in milliseconds)
end_time = time.time()

# Calculate total runtime
runtime = (end_time - start_time)

print(f"Total Runtime: {runtime} seconds")
print(f"{NUM_INVOCATIONS / runtime / 10}")
