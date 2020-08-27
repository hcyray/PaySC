pragma solidity >=0.4.21 <0.7.0;

import "@openzeppelin/contracts/math/SafeMath.sol";

contract Party{
  using SafeMath for uint;

  uint partyId = 0;
  uint maxHistSize = 100;
  uint maxActiveSize = 100;
  uint w = 10;
  int lambda1 = 1;
  int lambda2 = -1;



  struct ContractState{
    uint id;
    uint state; // 0 - close&default, 1 - close&fullfill, 2- active, 3- unresolve.
    uint value;
    uint createTime;
    uint dueTime;
    uint role; // 0 - payer, 1 - payee
  }

  struct PartyState{
    string license;
    address addr;
    int rep;
    uint histSize;
    ContractState[] histContract;
    uint activeSize;
    ContractState[] activeContract;
    uint unresolve;
  }
  mapping(uint => PartyState) parties;

  event PartyCreated(uint id);


  function registerParty(
        string memory license,
        address addr
    ) public {
        parties[partyId].license = license;
        parties[partyId].addr = addr;
        parties[partyId].rep = 0;
        parties[partyId].histSize = 0;
        parties[partyId].activeSize = 0;
        parties[partyId].unresolve = 0;
        emit PartyCreated(partyId);
        partyId = partyId + 1;
    }

  function getAddress(uint id) public view returns(address){
    return parties[id].addr;
  }
  //role: 0 - payer , 1- payee
  function addContract(uint id, uint scid, uint state, uint value, uint createTime,  uint dueTime, uint role) public{
    if (role==0){
      parties[id].histSize++;
      if (state == 3) {
        parties[id].unresolve++;
      }
      parties[id].histContract.push(ContractState(scid, state, value, createTime,  dueTime, role));
    } else {
      parties[id].activeSize++;
      parties[id].activeContract.push(ContractState(scid, state, value, createTime,  dueTime, role));
    }
  }

  function removeContract(uint id, uint x) public {
    for(uint i= 0; i < parties[id].histSize; i++){
      if (parties[id].histContract[i].dueTime + w < x ){
        parties[id].histSize--;
        if (parties[id].histSize>0){
          parties[id].histContract[i] = parties[id].histContract[parties[id].histSize];
        }
        delete parties[id].histContract[parties[id].histSize];
      }
    }
    parties[id].rep = 0;
    for(uint i=0; i < parties[id].histSize; i++){
      parties[id].rep += lambda1*int(parties[id].histContract[i].value) * int(parties[id].histContract[i].state) + lambda2*int(parties[id].histContract[i].value) * int(1-parties[id].histContract[i].state);
    }
  }

  function resolveContract(uint id, uint scid) public {
    parties[id].unresolve--;
    for (uint i=0; i < parties[id].histSize; i++){
      if (parties[id].histContract[i].id == scid){
        parties[id].histContract[i].state = 0;
        break;
      }
    }
  }

  function removeActiveContract(uint id, uint scid) public {
    for (uint i=0; i < parties[id].activeSize; i++){
      if (parties[id].activeContract[i].id == scid){
        parties[id].activeSize--;
        if (parties[id].activeSize>0){
          parties[id].activeContract[i] = parties[id].activeContract[parties[id].activeSize];
        }
        delete parties[id].activeContract[parties[id].activeSize];
      }
    }
  }

  function getRep(uint id) public view returns(int){
    return parties[id].rep;
  }

  function getIncome(uint id) public view returns(uint){
    uint income = 0;
    for (uint i=0; i < parties[id].activeSize; i++){
      income += parties[id].activeContract[i].value;
    }
    return income;
  }

  function isExists(uint id) public view returns (bool) {
    if(parties[id].addr!=address(0x0)){
        return true;
    } 
    return false;
  }

  function isLeagalParty(uint id) public view returns (bool) {
    if (parties[id].addr!=address(0x0) && parties[id].unresolve == 0){
      return true;
    } else {
      return false;
    }
  }

  function verifySignature(bytes32 hash, bytes memory signature, address signer) public pure returns (bool) {
    address addressFromSig = recoverSigner(hash, signature);
    return addressFromSig == signer;
  }
  /**
    * @dev Recover signer address from a message by using their signature
    * @param hash bytes32 message, the hash is the signed message. What is recovered is the signer address.
    * @param sig bytes signature, the signature is generated using web3.eth.sign(). Inclusive "0x..."
    */
  function recoverSigner(bytes32 hash, bytes memory sig) public pure returns (address) {
    require(sig.length == 65, "Require correct length");

    bytes32 r;
    bytes32 s;
    uint8 v;

    // Divide the signature in r, s and v variables
    assembly {
      r := mload(add(sig, 32))
      s := mload(add(sig, 64))
      v := byte(0, mload(add(sig, 96)))
    }

    // Version of signature should be 27 or 28, but 0 and 1 are also possible versions
    if (v < 27) {
      v += 27;
    }

    require(v == 27 || v == 28, "Signature version not match");

    return recoverSigner2(hash, v, r, s);
  }

  function recoverSigner2(bytes32 h, uint8 v, bytes32 r, bytes32 s) public pure returns (address) {
    bytes memory prefix = "\x19Ethereum Signed Message:\n32";
    bytes32 prefixedHash = keccak256(abi.encodePacked(prefix, h));
    address addr = ecrecover(prefixedHash, v, r, s);

    return addr;
  }  

}