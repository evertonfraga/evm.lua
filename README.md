# EVM.lua


<p align="center">
  <img src="./project-image.png" alt="Image description" width="350"/>
</p>

This project aims to implement a fully compliant EVM in Lua scripting language. It provides scripts to bind it to a Redis database, enabling it to run EVM functions.

## Installation

1. [Install Lua](https://www.lua.org), the scripting language. `brew install lua` on Mac.
1. [Install luarocks](https://luarocks.org/), a package manager for Lua: `brew install luarocks`
1. [Install Redis](https://redis.io/docs/install/install-redis/install-redis-on-mac-os/) and run `redis-server` to start the db.
1. Run `./load.sh` to load `evm.lua` script into Redis, with some test data.

## To-dos:
- [x] Create and deploy Lua functions that interprets EVM bytecode
- [x] Feed account storage based on initial list and block number
- [x] Implement basic benchmark scripts
- [ ] Nested call context
- [ ] Gas metering

## Opcodes implemented: 57/152
|✅`00`|✅`01`|✅`02`|✅`03`|✅`04`|✅`05`|`06`|`07`|`08`|`09`|`0A`|`0B`|  |  |  |  |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
|✅`10`|✅`11`|✅`12`|✅`13`|✅`14`|✅`15`|`16`|`17`|`18`|`19`|`1A`|`1B`|`1C`|`1D`|  |  |
|`20`|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|`30`|`31`|`32`|`33`|`34`|`35`|`36`|`37`|`38`|`39`|`3A`|`3B`|`3C`|`3D`|`3E`|`3F`|
|`40`|`41`|`42`|`43`|`44`|`45`|`46`|`47`|`48`|`49`|`4A`|  |  |  |  |  |
|✅`50`|`51`|`52`|`53`|✅`54`|`55`|✅`56`|✅`57`|`58`|`59`|`5A`|✅`5B`|`5C`|`5D`|`5E`|✅`5F`|
|✅`60`|✅`61`|✅`62`|✅`63`|✅`64`|✅`65`|✅`66`|`67`|`68`|`69`|`6A`|`6B`|`6C`|`6D`|`6E`|`6F`|
|`70`|`71`|`72`|`73`|`74`|`75`|`76`|`77`|`78`|`79`|`7A`|`7B`|`7C`|`7D`|`7E`|`7F`|
|✅`80`|✅`81`|✅`82`|✅`83`|✅`84`|✅`85`|✅`86`|✅`87`|✅`88`|✅`89`|✅`8A`|✅`8B`|✅`8C`|✅`8D`|✅`8E`|✅`8F`|
|✅`90`|✅`91`|✅`92`|✅`93`|✅`94`|✅`95`|✅`96`|✅`97`|✅`98`|✅`99`|✅`9A`|✅`9B`|✅`9C`|✅`9D`|✅`9E`|✅`9F`|
|`A0`|`A1`|`A2`|`A3`|`A4`|  |  |  |  |  |  |  |  |  |  |  |
|`B0`|`B1`|`B2`|  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
|`F0`|`F1`|`F2`|`F3`|`F4`|`F5`|  |  |  |  |`FA`|  |  |`FD`|  |`FF`|


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
