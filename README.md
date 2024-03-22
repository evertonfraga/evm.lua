# EVM Lua


<p align="center">
  <img src="./project-image.png" alt="Image description" width="350"/>
</p>


Proposal: using Redis to cache arbitrary blockchain account storage, with support for EVM method calls (eth_call) with payload and data.

## Installation

1. [Install Lua](https://www.lua.org), the scripting language. `brew install lua` on Mac.
1. [Install luarocks](https://luarocks.org/), a package manager for Lua: `brew install luarocks`
1. [Install Redis](https://redis.io/docs/install/install-redis/install-redis-on-mac-os/) and run `redis-server` to start the db.
1. Run `./load.sh` to load `evm.lua` script into Redis, with some test data.

## To-dos:
- [x] Create and deploy Lua functions that interprets EVM bytecode
- [ ] Feed account storage based on initial list and block number
- [ ] Implement benchmark script using Flood.

- Main opcodes to implement:
- [ ] push16-push32
- [ ] sha3

## Install redis-cli on amazon linux 2

```sh
sudo yum install wget -y
sudo yum install tcl -y
sudo yum install gcc -y
sudo yum install centos-release-scl -y
sudo yum install devtoolset-9-gcc devtooset-g-gcc-c++ devtoolset-9-binutils -y
sudo yum install openssl-devel* -y
```

## Reference links

- [Lua programming guide](https://www.lua.org/pil/contents.html)
- [EVM reference](https://evm.codes)
- [Official EVM state tests](https://github.com/ethereum/tests/blob/develop/GeneralStateTests/stStackTests/shallowStack.json)
- [Testing local functions](https://github.com/lunarmodules/busted/issues/605#issuecomment-511490382)

Use Redis triggers to do garbage collection:
https://redis.io/docs/interact/programmability/triggers-and-functions/examples/


EVM.init should support:
- new attributes: calldata and depth, starting at 0/1
for each new CALL opcode-type, instantiate a new EVM.init, passing arguments.
- RETURN should return data from memory, kill the execution context branch. decrement depth. If depth == top depth, return function to external
