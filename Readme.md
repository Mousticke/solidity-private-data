When we think about private data in general, we think that any program or software interacting with our smart-contract cannot access to this variable.
Usually, when we have a private variable in an OOP, we use a getter and a setter for manipulating or reading the data.
Sometimes, we can see that the private visibility is used to store some sensitive data and we don't want anyone to read that data.

Let's say in our smart contract, we define a private state variable to store a password, a secret key or whatever. So that nobody can read or modify the data.
But it doesn't mean that we can't access to this data.

**A private state variable can be read**

Let's jump into the code and some explanation
You can go to this repo to get the source code or follow along with me.

# Prerequisites

- [NodeJS ](https://nodejs.org/en/)
- [Truffle](https://nodejs.org/en/)

```shell
npm install -g truffle
```

- [Web3JS](https://web3js.readthedocs.io/en/v1.5.2/getting-started.html#adding-web3-js)

```shell
npm install web3
```

- [Ganache](https://trufflesuite.com/ganache/)

# Instantiate Truffle project

First, create a truffle project within a directory with the following command :

```shell
truffle init
```

Then create a contract

```shell
truffle create contract TestPrivate
```

# Code

Now we have a contract created, copy paste this code

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract TestPrivate {

  bool public slot_boolean = true;        // → slot 0 : 1 byte
  address public owner = msg.sender;                   // → slot 0 : 20 bytes
  uint256 public slot_uint256 = 1000;     // → slot 1 : 32 bytes
  uint[2] public data;                    // → slot 2 : 32 bytes and slot 3 : 32 bytes (one slot per element)
  bytes32 private secret_data;            // → slot 4 : 32 bytes

  struct User{
    uint id;
    uint8 role;
    address userAddress;
    bytes32 password;
  }

  User[] private users;                // → slot 5 starts at keccak(5) for first user
                                      // → second user at keccack(5) + (3 → slot used for the storing one struct of user)

  constructor(bytes32 _secret_data) {
    secret_data = _secret_data;
  }

  function enrollUser(uint8 _role, bytes32 _password) external {
    User memory user = User({
      id: users.length,
      role: _role,
      userAddress: msg.sender,
      password: _password
    });

    users.push(user);
  }
}
```

Now we have the code, let's see how the EVM stores the variables

# Slots in the EVM

The EVM will store the state variables inside an array in a compact way. That means multiple values can use the same slot. A slot can store up to 32bytes.
So when a variable in the slot is lower than 32 bytes, if the next variable can fit in the remaining space, it will be stored in the same slot.
(It's better to use 32 bytes variables for gas usage but it's another subject).

Let's see in our code, how is it stored.
Our first variable is a boolean set to true. It will be stored in the slot 0 and takes 1 byte.

| slot | type | 32 bytes slot                                                      |
| ---- | ---- | ------------------------------------------------------------------ |
| 0    | bool | 0x0000000000000000000000000000000000000000000000000000000000000001 |

Next, we have an address type is 20 bytes. But in the slot 0, we still have enough space to store 20 bytes.
So we compact two variables inside this slot

| slot | type           | 32 bytes slot                                                      |
| ---- | -------------- | ------------------------------------------------------------------ |
| 0    | address & bool | 0x0000000000000000000000aC86db09Aa6756D9606d638bFb3a3A0f7669850401 |

So we now have 11 bytes remaining space. (20 + 1 = 21 bytes used)

After that, we have a uint256 with a value of 1000 (10). A uint256 is unsigned integer with a size of 256 bits (32 bytes). So the entire slot 1 will store this variable.
So the storage will be :

| slot | type           | 32 bytes slot                                                      |
| ---- | -------------- | ------------------------------------------------------------------ |
| 0    | address & bool | 0x0000000000000000000000aC86db09Aa6756D9606d638bFb3a3A0f7669850401 |
| 1    | uint256 (1000) | 0x00000000000000000000000000000000000000000000000000000000000003e8 |

> If this uint was a uint128, whe would store 16 bytes inside the slot 0 because we have enough space. But if the slot 0 was full, we would store the data inside the next slot with a remaining space of 16 bytes (32 bytes - 16 bytes). The EVM does some operation to convert a 16 bytes data to fit inside a 32 bytes slot by adding some 0 in front of the data.

Then we have an array of 2 elements of uint256. Each element is stored inside a slot. Because one element is a 32 bytes size, we use 2 slots for the entire array.

| slot | type           | 32 bytes slot                                                      |
| ---- | -------------- | ------------------------------------------------------------------ |
| 0    | address & bool | 0x0000000000000000000000aC86db09Aa6756D9606d638bFb3a3A0f7669850401 |
| 1    | uint256 (1000) | 0x00000000000000000000000000000000000000000000000000000000000003e8 |
| 2    | uint256(0)     | 0x0000000000000000000000000000000000000000000000000000000000000000 |
| 3    | uint256(1)     | 0x0000000000000000000000000000000000000000000000000000000000000000 |

We store the private bytes32 inside the slot 4.

| slot | type           | 32 bytes slot                                                      |
| ---- | -------------- | ------------------------------------------------------------------ |
| 0    | address & bool | 0x0000000000000000000000aC86db09Aa6756D9606d638bFb3a3A0f7669850401 |
| 1    | uint256 (1000) | 0x00000000000000000000000000000000000000000000000000000000000003e8 |
| 2    | uint256(0)     | 0x0000000000000000000000000000000000000000000000000000000000000000 |
| 3    | uint256(1)     | 0x0000000000000000000000000000000000000000000000000000000000000000 |
| 4    | bytes32        | 0x0000000000000000000000000000000000000000000000000000000000000000 |

Next we have a struct of User. Inside that struct, we have :

1.  id - uint (32 bytes)
2.  role - uint8 (1 byte)
3.  userAddress - address (20 bytes)
4.  password - bytes32 (32 bytes)

So inside the array of User, we start to store at the slot 5. To know where to find the first user, we convert the number of the slot into a hash (keccak256). If we access to this slot, we have the id. Then if we increment the hash by one we access to the next slot which contains the role (1 byte) and the address (20 bytes).
If we increment the hash by 2, we access to the third slot, which contains the password.
If you want to access to the id of the second user, you increment the hash by 3 and so on...

# Deploy the contract

Now let's deploy the contract.
We have a constructor that takes a parameter of a bytes32. Let's pass this argument `0x0000000000000000000000000000000000007365637265742069732068657265`.
It's the string `secret is here` in hex representation.

To deploy the contract, we first need to create the `migration` file for truffle. For that, you need to compile the smart contract because we need to access to the artifact. Then create a file inside the migrations folder.

- Run
  ```shell
  truffle compile
  ```
- Add `2_deploy_TestPrivate.js`

The output from the compile command should look like this :

```shell
$ truffle compile

Compiling your contracts...
===========================
> Compiling .\contracts\Migrations.sol
> Compiling .\contracts\TestPrivate.sol
> Artifacts written to D:\Documents\Development\Ether\security\solidity-private-data\build\contracts
> Compiled successfully using:
   - solc: 0.8.9+commit.e5eed63a.Emscripten.clang
```

Then add this code inside the file `2_deploy_TestPrivate.js`

After that you need to check if you have a network enabled inside your truffle config. (In my case, I will run a local network with ganache)
Your truffle config should look like this :

```javascript
module.exports = {
  networks: {
    ganache: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 7545, // Standard Ethereum port (default: none)
      network_id: "*", // Any network (default: none)
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.9", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {          // See the solidity docs for advice about optimization and evmVersion
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  },
      //  evmVersion: "byzantium"
      // }
    },
  },
};
```

Once you have all the setup done, after running the command `truffle migrate --network ganache`, you should see the following output

```shell
$ truffle migrate --network ganache

Compiling your contracts...
===========================
> Compiling .\contracts\Migrations.sol
> Compiling .\contracts\TestPrivate.sol
> Artifacts written to D:\Documents\Development\Ether\security\solidity-private-data\build\contracts
> Compiled successfully using:
   - solc: 0.8.9+commit.e5eed63a.Emscripten.clang



Starting migrations...
======================
> Network name:    'ganache'
> Network id:      5777
> Block gas limit: 6721975 (0x6691b7)


1_initial_migration.js
======================

   Deploying 'Migrations'
   ----------------------
   > transaction hash:    0xb6767a41e6067e2ec91eb8160df8a52064366aaa89768e7377dd6a5f9fc312ac
   > Blocks: 0            Seconds: 0
   > contract address:    0xA441f0E978c08E70c3249d97Dd542E7E37bEc06D
   > block number:        618
   > block timestamp:     1640659167
   > account:             0x009d6EF647f472b543A6057b443a72Dff6e61c7a
   > balance:             96.52405552
   > gas used:            248842 (0x3cc0a)
   > gas price:           20 gwei
   > value sent:          0 ETH
   > total cost:          0.00497684 ETH


   > Saving migration to chain.
   > Saving artifacts
   -------------------------------------
   > Total cost:          0.00497684 ETH


2_deploy_TestPrivate.js
=======================

   Deploying 'TestPrivate'
   -----------------------
   > transaction hash:    0x764f973c29ed5937b26728f80689387fcf99b38d96a635bcdf43edc17a331c1b
   > Blocks: 0            Seconds: 0
   > contract address:    0xd3a66714eB418B33f78c46FbC1B4996c6dE2F705
   > block number:        620
   > block timestamp:     1640659168
   > account:             0x009d6EF647f472b543A6057b443a72Dff6e61c7a
   > balance:             96.5160722
   > gas used:            356653 (0x5712d)
   > gas price:           20 gwei
   > value sent:          0 ETH
   > total cost:          0.00713306 ETH


   > Saving migration to chain.
   > Saving artifacts
   -------------------------------------
   > Total cost:          0.00713306 ETH


Summary
=======
> Total deployments:   2
> Final cost:          0.0121099 ETH
```

In ganache, we can see our contract deployed (You need to add the truffle config file)
IMAGE HERE

Inside you json file of the previously compiled contract, you should see this object

```json
"networks": {
    "5777": {
        "events": {},
        "links": {},
        "address": "0xd3a66714eB418B33f78c46FbC1B4996c6dE2F705",
        "transactionHash": "0x764f973c29ed5937b26728f80689387fcf99b38d96a635bcdf43edc17a331c1b"
    }
},
```

So now our contract is deployed and ready to use, we can add some data inside the users array.

# Interact with the smart contract

Since we have a client (Ganache), we run the command `truffle console`
See if it works by returning the list of the accounts

```shell
truffle(ganache)> let accounts = await web3.eth.getAccounts()
undefined
truffle(ganache)> accounts
[
  '0x009d6EF647f472b543A6057b443a72Dff6e61c7a',
  '0x4EBE31e37c016253DE9B8994514Da6cBCB57f0a5',
  '0xC66A8fBAF9F95CCe86AefB8e713029E2aa9c7E8d',
  '0xF22f46120471166fb7029990D4eCBaCb63e575B4',
  '0x7B4794aD644543b80b71c1243185E37AEA50B403',
  '0xbe8eC832Ea864366F789AB1458358e4506228075',
  '0x108BdEa3473a7488377C9FbE5b12078bf311Ca16',
  '0xbdEe79e2C8CA3311B9C8531410f09567F22F4FEd',
  '0x579Ed8B42541E0877D9e2425D32a67127f22b0A3',
  '0xA3AD8DE6b1BDe5DacF715E4008866b3c12a5def0'
]
truffle(ganache)>
```

Now, let's create an instance of the smart contract

```shell
truffle(ganache)> let instance = await TestPrivate.deployed()
undefined
truffle(ganache)> instance
 ...
 contractName: 'TestPrivate',
      abi: [Array],
      metadata: ...
 ...
```

# Access to the slot

Now we have our smart contract instance, let's see how we access to the slots.

First we need the address of the smart contract

```shell
truffle(ganache)> let address = await instance.address
undefined
truffle(ganache)> address
'0xd3a66714eB418B33f78c46FbC1B4996c6dE2F705'
```

We will use our address to get the data inside the storage with web3

## Slot 0

For the slot 0, we have

```shell
truffle(ganache)> let instance = await TestPrivate.deployed()
undefined
truffle(ganache)> let address = await instance.address
undefined
truffle(ganache)> address
'0xB3884D48eA4f9CbC6bCE90E3D58d193C6c6d719C'
truffle(ganache)> let slot0 = await web3.eth.getStorageAt(address, 0, console.log)
null 0x9d6ef647f472b543a6057b443a72dff6e61c7a01
undefined
truffle(ganache)> slot0
'0x9d6ef647f472b543a6057b443a72dff6e61c7a01'
```

We can see our owner address `9d6ef647f472b543a6057b443a72dff6e61c7a` and our boolean value `01`
You can check the owner address

```shell
truffle(ganache)> await instance.owner()
'0x009d6EF647f472b543A6057b443a72Dff6e61c7a'
```

## Slot 1

```shell
truffle(ganache)> let slot1 = await web3.eth.getStorageAt(address, 1, console.log)
null 0x03e8
undefined
truffle(ganache)> slot1
'0x03e8'
truffle(ganache)>
```

We can see the uint256 value 1000 in hex.

```shell
truffle(ganache)> parseInt(0x3e8, 10)
1000
```

## Slot 2 and 3

As I said earlier, the slot 2 and 3 contains the value of the uint256 array. Each value are stored in one slot due to their size.

```shell
truffle(ganache)> let slot2 = await web3.eth.getStorageAt(address, 2, console.log)
null 0x0
undefined
truffle(ganache)> slot2
'0x0'
truffle(ganache)> let slot3 = await web3.eth.getStorageAt(address, 3, console.log)
null 0x0
undefined
truffle(ganache)> slot3
'0x0'
```

## Slot 4

Here comes the funny part. We have a private state variable. Let's see what we have

```shell
truffle(ganache)> let slot4 = await web3.eth.getStorageAt(address, 4, console.log)
null 0x7365637265742069732068657265
undefined
truffle(ganache)> slot4
'0x7365637265742069732068657265'
```

We can see the hex value `0x7365637265742069732068657265`. Since it is a byte32 state variable, let's convert into an alphabet representation

```shell
truffle(ganache)> let asciiPrivateData = await web3.utils.toAscii('0x7365637265742069732068657265')
undefined
truffle(ganache)> asciiPrivateData
'secret is here'
```

We can see that we can clearly read the data.

## Slot 5

In the user array, we first add 2 users.

```shell
truffle(ganache)> await instance.enrollUser(1, web3.utils.toHex("secret user1"))
{
  tx: '0xa9c1e069d453a41cce948f3c6779dc8d02a3ee2e50b3b4cba9866bc5f4c4aa4a',
  receipt: {
    transactionHash: '0xa9c1e069d453a41cce948f3c6779dc8d02a3ee2e50b3b4cba9866bc5f4c4aa4a',
    transactionIndex: 0,
    blockHash: '0x05ec32043c20202580f971711715d2c4c3483723703d3879b859080c92626ff0',
    blockNumber: 626,
    from: '0x009d6ef647f472b543a6057b443a72dff6e61c7a',
    to: '0xb3884d48ea4f9cbc6bce90e3d58d193c6c6d719c',
    gasUsed: 87357,
    cumulativeGasUsed: 87357,
    contractAddress: null,
    logs: [],
    status: true,
    logsBloom: '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    rawLogs: []
  },
  logs: []
}
truffle(ganache)> await instance.enrollUser(2, web3.utils.toHex("secret user2"))
{
  tx: '0xedef6f68f3e742b6ec41e10e7256f1fceba84b247f2b1d83ec66b367f04511bb',
  receipt: {
    transactionHash: '0xedef6f68f3e742b6ec41e10e7256f1fceba84b247f2b1d83ec66b367f04511bb',
    transactionIndex: 0,
    blockHash: '0x4f6f86923646c4103d9b5eaf413f0ef2cebe175ea6b550fb971fd48a08ff52e6',
    blockNumber: 627,
    from: '0x009d6ef647f472b543a6057b443a72dff6e61c7a',
    to: '0xb3884d48ea4f9cbc6bce90e3d58d193c6c6d719c',
    gasUsed: 91557,
    cumulativeGasUsed: 91557,
    contractAddress: null,
    logs: [],
    status: true,
    logsBloom: '0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
    rawLogs: []
  },
  logs: []
}
```

Now we have the 2 user, let's run our methods to get the storage at the slot 5

```shell
truffle(ganache)> let slot5 = await web3.eth.getStorageAt(address, 5, console.log)
null 0x02
undefined
truffle(ganache)> slot5
'0x02'
```

We can see that we have 2 User inside our array. The first user should be stored at the hash of the slot 5

```shell
truffle(ganache)> let hashFirstUser = await web3.utils.soliditySha3({type: "uint", value: 5})
undefined
truffle(ganache)> hashFirstUser
'0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db0'
truffle(ganache)>
```

Now, get the first user id

```shell
truffle(ganache)> let slot_user1_id = await web3.eth.getStorageAt(address, hashFirstUser, console.log)
null 0x0
undefined
truffle(ganache)> slot_user1_id
'0x0'
truffle(ganache)>
```

It should equal 0 because the id is the length of the array before we push the struct.

To get th user role and address, we need to read the next slot by incrementing the hash by one
`0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db0` → `0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db1`

```shell
truffle(ganache)> let slot_user1_roleAndAddress = await web3.eth.getStorageAt(address, '0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db1', console.log)
null 0x9d6ef647f472b543a6057b443a72dff6e61c7a01
undefined
truffle(ganache)> slot_user1_roleAndAddress
'0x9d6ef647f472b543a6057b443a72dff6e61c7a01'
```

We can see the role `01` and the msg.sender value. (Which is the same as the owner in this case) `0x9d6ef647f472b543a6057b443a72dff6e61c7a`.

Then, we access to the password of the user by incrementing again the hash by 2
`0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db0` → `0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db2`

```shell
truffle(ganache)> let slot_user1_password = await web3.eth.getStorageAt(address, '0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db2', console.log)
null 0x7365637265742075736572310000000000000000000000000000000000000000
undefined
truffle(ganache)> slot_user1_password
'0x7365637265742075736572310000000000000000000000000000000000000000'
truffle(ganache)> await web3.utils.toAscii('0x7365637265742075736572310000000000000000000000000000000000000000')
'secret user1\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
```

We can clearly see the password of the user even though the state variable is private.

You can guess that if you want to see the data of the user 2, you need to increment the hash by 3 (3 slots for one user due to our structure)

```shell
truffle(ganache)> let slot_user2_id = await web3.eth.getStorageAt(address, '0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db3', console.log)
null 0x01
undefined
truffle(ganache)> slot_user2_id
'0x01'
```

We can access to the password of the second user by incrementing the hash by 5

```shell
truffle(ganache)> let slot_user2_password = await web3.eth.getStorageAt(address, '0x036b6384b5eca791c62761152d0c79bb0604c104a5fb6f4eb0703f3154bb3db5', console.log)
null 0x7365637265742075736572320000000000000000000000000000000000000000
undefined
truffle(ganache)> await web3.utils.toAscii('0x7365637265742075736572320000000000000000000000000000000000000000')
'secret user2\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00'
```

# Conclusion

Do not assume that because you have a private state variable, we cannot access to the data. The recommendation is :
**Do not store sensitive data on the blockchain.**

Thank you very much.
You can get the code here :
