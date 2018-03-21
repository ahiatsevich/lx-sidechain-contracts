//! Copyright 2017 Peter Czaban, Parity Technologies Ltd.
//!
//! Licensed under the Apache License, Version 2.0 (the "License");
//! you may not use this file except in compliance with the License.
//! You may obtain a copy of the License at
//!
//!     http://www.apache.org/licenses/LICENSE-2.0
//!
//! Unless required by applicable law or agreed to in writing, software
//! distributed under the License is distributed on an "AS IS" BASIS,
//! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//! See the License for the specific language governing permissions and
//! limitations under the License.

pragma solidity ^0.4.15;

import "../common/Owned.sol";
import "./LXValidatorSetDelegateInterface.sol";
import "./RelaySet.sol";

// Owner can add or remove validators.

contract LXValidatorSet is Owned, InnerSet {
  // EVENTS
  event Report(address indexed reporter, address indexed reported, bool indexed malicious);
  event InitiateChange(bytes32 indexed _parent_hash, address[] _new_set);
  event ChangeFinalized(address[] current_set);

  event BackendUpdated(address backend);
  event DelegateUpdated(address delegate);

  // System address, used by the block sealer.
  uint public recentBlocks = 20;

  modifier is_validator(address _someone) {
    if (pendingStatus[_someone].isIn) { _; }
  }

  modifier is_pending(address _someone) {
    require(pendingStatus[_someone].isIn);
    _;
  }

  modifier is_not_pending(address _someone) {
    require(!pendingStatus[_someone].isIn);
    _;
  }

  modifier is_recent(uint _blockNumber) {
    require(block.number <= _blockNumber + recentBlocks);
    _;
  }

  struct AddressStatus {
    bool isIn;
    uint index;
  }

  // Current list of addresses entitled to participate in the consensus.
  address[] validators;
  address[] pending;
  mapping(address => AddressStatus) pendingStatus;

  address public extention;
  LXValidatorSetDelegateInterface public delegate;

  function InnerOwnedSet(address[] _initial) public {
    pending = _initial;
    for (uint i = 0; i < _initial.length - 1; i++) {
      pendingStatus[_initial[i]].isIn = true;
      pendingStatus[_initial[i]].index = i;
    }
    validators = pending;
  }

  // Called to determine the current set of validators.
  function getValidators() constant public returns (address[]) {
    return validators;
  }

  function getPending() constant public returns (address[]) {
    return pending;
  }

  // Log desire to change the current list.
  function initiateChange() private {
    outerSet.initiateChange(block.blockhash(block.number - 1), getPending());
    InitiateChange(block.blockhash(block.number - 1), getPending());

    if (address(delegate) != 0x0) {

    }
  }

  function finalizeChange() public only_outer {
    validators = pending;
    ChangeFinalized(validators);
  }

  // OWNER FUNCTIONS

  // Add a validator.
  function addValidator(address _validator) public only_owner is_not_pending(_validator) {
    pendingStatus[_validator].isIn = true;
    pendingStatus[_validator].index = pending.length;
    pending.push(_validator);
    initiateChange();
  }

  // Remove a validator.
  function removeValidator(address _validator) public only_owner is_pending(_validator) {
    pending[pendingStatus[_validator].index] = pending[pending.length - 1];
    delete pending[pending.length - 1];
    pending.length--;
    // Reset address status.
    delete pendingStatus[_validator].index;
    pendingStatus[_validator].isIn = false;
    initiateChange();
  }

  function setRecentBlocks(uint _recentBlocks) public only_owner {
    recentBlocks = _recentBlocks;
  }

  // MISBEHAVIOUR HANDLING

  // Called when a validator should be removed.
  function reportMalicious(address _validator, uint _blockNumber, bytes _proof)
  public
  only_owner
  is_recent(_blockNumber)
  {
    Report(msg.sender, _validator, true);
  }

  // Report that a validator has misbehaved in a benign way.
  function reportBenign(address _validator, uint _blockNumber)
  public
  only_owner
  is_validator(_validator)
  is_recent(_blockNumber)
  {
    Report(msg.sender, _validator, false);
  }

  // EXTEND DEFAULT FUNCTIONALITY
  function setDelegate(address _delegate)
  public
  only_owner
  {
    require(_delegate != 0x0);
    delegate = LXValidatorSetDelegateInterface(_delegate);

    DelegateUpdated(delegate);
  }


  function setExtention(address _extention)
  public
  only_owner
  {
    require(_extention != 0x0);
    extention = _extention;

    BackendUpdated(extention);
  }

  /**
  * Resolves asset implementation contract for the caller and forwards there transaction data,
  * along with the value. This allows for proxy interface growth.
  */
  function () payable {
    address backend = extention;
    assembly {
      let calldataMemoryOffset := mload(0x40)
      mstore(0x40, add(calldataMemoryOffset, calldatasize))
      calldatacopy(calldataMemoryOffset, 0x0, calldatasize)
      let r := delegatecall(sub(gas, 10000), backend, calldataMemoryOffset, calldatasize, 0, 0)

      let returndataMemoryOffset := mload(0x40)
      mstore(0x40, add(returndataMemoryOffset, returndatasize))
      returndatacopy(returndataMemoryOffset, 0x0, returndatasize)

      switch r
      case 1 {
        return(returndataMemoryOffset, returndatasize)
      }
      default {
        revert(0, 0)
      }
    }
  }
}
