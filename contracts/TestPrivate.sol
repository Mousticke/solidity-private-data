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
