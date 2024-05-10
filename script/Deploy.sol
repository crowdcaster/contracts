// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Script} from 'forge-std/Script.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {Metadata} from 'contracts/utils/Metadata.sol';
import {IRegistry} from 'interfaces/utils/IRegistry.sol';

contract CreateProfile is Script {
  struct ProfileParams {
    uint256 _nonce;
    string _name;
    Metadata _metadata;
    address _owner;
    address[] _members;
  }

  struct AlloParams {
    address _alloRegistry;
  }

  /// @notice Deployment parameters for each chain
  mapping(uint256 _chainId => ProfileParams _params) internal _profileParams;
  mapping(uint256 _chainId => AlloParams _params) internal _alloParams;

  function setUp() public {
    // Optimism Sepolia
    Metadata memory _metadata = Metadata(1, 'ipfs://ipfs_address');
    address[] memory _members = new address[](1);
    _members[0] = msg.sender;
    _profileParams[11_155_111] = ProfileParams(4, 'PORCO DIO', _metadata, msg.sender, _members);

    _alloParams[11_155_111] = AlloParams(0x4AAcca72145e1dF2aeC137E1f3C5E3D75DB8b5f3);
  }

  function run() public {
    ProfileParams memory _params = _profileParams[block.chainid];
    AlloParams memory _allo = _alloParams[block.chainid];

    // create a profile on allo
    IRegistry _registry = IRegistry(_allo._alloRegistry);
    vm.startBroadcast();
    _registry.createProfile(_params._nonce, _params._name, _params._metadata, _params._owner, _params._members);
    vm.stopBroadcast();
  }
}
