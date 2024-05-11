// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

// External Libraries
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';
// Interfaces
import {IAllo} from 'interfaces/utils/IAllo.sol';
// "../../core/interfaces/IAllo.sol"
import {IRegistry} from 'interfaces/utils/IRegistry.sol';
// Core Contracts
import {BaseStrategy} from 'contracts/utils/BaseStrategy.sol';
// Internal Libraries
import {Metadata} from 'contracts/utils/Metadata.sol';

/// @title Kickstarter Strategy
/// @author @0xr3x <rex@defi.sucks>
/// @notice Simple strategy for Kickstarter-style allocation with and management. Based on RFP Strategy.

contract KickstarterStrategy is BaseStrategy, ReentrancyGuard {
  /// ================================
  /// ========== Struct ==============
  /// ================================

  /// @notice Stores the details of the recipients.
  struct Recipient {
    bool useRegistryAnchor;
    address recipientAddress;
    Metadata metadata;
  }

  /// @notice Stores the details needed for initializing strategy
  struct InitializeParams {
    uint256 minimumThreshold;
    bool useRegistryAnchor;
    address acceptedController;
    uint256 fundraiseDuration;
    bool metadataRequired;
    Recipient recipient;
  }

  /// ================================
  /// ========== Storage =============
  /// ================================

  /// @notice Flag to indicate whether to use the registry anchor or not
  bool public useRegistryAnchor;

  /// @notice Flag to indicate whether metadata is required or not
  bool public metadataRequired;

  /// @notice The accepted controller who can mark the fundraising campaign as unsuccessful
  address public acceptedController;

  /// @notice The registry contract interface
  IRegistry private _registry;

  /// @notice The minimum threshold to be reached for the pool to be active
  uint256 public minimumThreshold;

  /// @notice The limit by which the fundraise roind is completed
  uint64 public fundraiseStartTime;
  uint64 public fundraiseEndTime;

  /// @notice This maps accepted recipients to their details
  /// @dev 'recipientId' to 'Recipient'
  Recipient internal _recipient;

  /// ===============================
  /// ========== Events =============
  /// ===============================

  /// @notice Emitted when a recipient updates their registration
  /// @param _recipient address of the recipient
  /// @param data The encoded data - (address recipientId, address recipientAddress, Metadata metadata)
  /// @param sender The sender of the transaction
  event UpdatedRegistration(address indexed _recipient, bytes data, address sender);

  /// @notice Emitted when the pool timestamps are updated
  /// @param fundraiseStartTime The start time for the fundraise
  /// @param fundraiseEndTime The end time for the registration
  /// @param sender The sender of the transaction
  event TimestampsUpdated(uint64 fundraiseStartTime, uint64 fundraiseEndTime, address sender);

  /// @notice Emitted when the fundraise reaches its minimum threshold
  /// @param flag The flag to set the pool to active or inactive
  /// @param recipient The recipient address
  /// @param amount The amount raised
  /// @param sender The sender of the transaction
  event FundraiseSuccessful(bool flag, address indexed recipient, uint256 amount, address sender);

  /// @notice Emitted when the fundraise does not reach its minimum threshold
  /// @param flag The flag to set the pool to active or inactive
  /// @param recipient The recipient address
  /// @param amount The amount raised
  /// @param sender The sender of the transaction
  event FundraiseFailed(bool flag, address indexed recipient, uint256 amount, address sender);

  /// ===============================
  /// ========== Errors =============
  /// ===============================

  /// @notice Thrown when the pool manager attempts to the lower the max bid
  error AMOUNT_TOO_LOW();

  /// ===============================
  /// ======== Constructor ==========
  /// ===============================

  /// @notice Constructor for the RFP Simple Strategy
  /// @param _allo The 'Allo' contract
  /// @param _name The name of the strategy
  constructor(address _allo, string memory _name) BaseStrategy(_allo, _name) {}

  /// ===============================
  /// ========= Initialize ==========
  /// ===============================

  // @notice Initialize the strategy
  /// @param _poolId ID of the pool
  /// @param _data The data to be decoded
  /// @custom:data (uint256 _maxBid, bool registryGating, bool metadataRequired)
  function initialize(uint256 _poolId, bytes memory _data) external virtual override {
    (InitializeParams memory initializeParams) = abi.decode(_data, (InitializeParams));
    __KickstarterStrategy_init(_poolId, initializeParams);
    emit Initialized(_poolId, _data);
    emit Registered(initializeParams.recipient.recipientAddress, _data, msg.sender);
  }

  /// @notice This initializes the BaseStrategy
  /// @dev You only need to pass the 'poolId' to initialize the BaseStrategy and the rest is specific to the strategy
  /// @param _initializeParams The initialize params
  function __KickstarterStrategy_init(uint256 _poolId, InitializeParams memory _initializeParams) internal {
    // Initialize the BaseStrategy
    __BaseStrategy_init(_poolId);

    // Set the strategy specific variables
    useRegistryAnchor = _initializeParams.useRegistryAnchor;
    metadataRequired = _initializeParams.metadataRequired;
    acceptedController = _initializeParams.acceptedController;
    minimumThreshold = _initializeParams.minimumThreshold;
    fundraiseStartTime = uint64(block.timestamp);
    fundraiseEndTime = uint64(block.timestamp + _initializeParams.fundraiseDuration);

    _registry = allo.getRegistry();

    // Set the pool to active - this is required for the strategy to work and distribute funds
    // NOTE: There may be some cases where you may want to not set this here, but will be strategy specific
    _setPoolActive(true);
  }

  /// ===============================
  /// ============ Views ============
  /// ===============================

  /// @notice Return the payout for acceptedRecipientId
  function getPayouts(address[] memory, bytes[] memory) external view override returns (PayoutSummary[] memory) {
    PayoutSummary[] memory payouts = new PayoutSummary[](1);
    payouts[0] = _getPayout(_recipient.recipientAddress, abi.encodePacked(address(0)));
    return payouts;
  }

  /// ===============================
  /// ======= External/Custom =======
  /// ===============================

  /// @notice Toggle the status between active and inactive.
  /// @dev 'msg.sender' must be a pool manager to close the pool. Emits a 'PoolActive()' event.
  /// @param _flag The flag to set the pool to active or inactive
  function setPoolActive(bool _flag) external onlyPoolManager(msg.sender) {
    _setPoolActive(_flag);
  }

  /// @notice Withdraw the tokens from the pool
  /// @dev Callable by the pool manager
  /// @param _token The token to withdraw
  function withdraw(address _token) external virtual onlyPoolManager(msg.sender) onlyInactivePool {
    uint256 amount = _getBalance(_token, address(this));

    // Transfer the tokens to the 'msg.sender' (pool manager calling function)
    _transferAmount(_token, msg.sender, amount);
  }

  /// ====================================
  /// ============ Internal ==============
  /// ====================================

  function _allocate(bytes memory _data, address _sender) internal override {}

  function _distribute(address[] memory _recipientIds, bytes memory _data, address _sender) internal override {}

  function _getRecipientStatus(address _recipientId) internal view virtual override returns (Status) {
    return Status.Accepted;
  }

  function _registerRecipient(bytes memory _data, address _sender) internal virtual override returns (address) {
    return address(0);
  }

  function _beforeIncreasePoolAmount(uint256 _amount) internal virtual override {
    // require(_amount >= minimumThreshold, 'AMOUNT_TOO_LOW');
    // require(block.timestamp >= fundraiseStartTime && block.timestamp <= fundraiseEndTime, 'FUNDRAISE_NOT_ACTIVE');
  }

  /// @notice Check if sender is a profile owner or member.
  /// @param _anchor Anchor of the profile
  /// @param _sender The sender of the transaction
  /// @return 'true' if the sender is the owner or member of the profile, otherwise 'false'
  function _isProfileMember(address _anchor, address _sender) internal view returns (bool) {
    IRegistry.Profile memory profile = _registry.getProfileByAnchor(_anchor);
    return _registry.isOwnerOrMemberOfProfile(profile.id, _sender);
  }

  /// @notice Get the payout summary for the accepted recipient.
  /// @return Returns the payout summary for the accepted recipient
  function _getPayout(address _recipientId, bytes memory _data) internal view override returns (PayoutSummary memory) {
    return PayoutSummary(_recipient.recipientAddress, address(this).balance);
  }

  /// @notice Checks if address is eligible allocator.
  /// @dev This is used to check if the allocator is a pool manager and able to allocate funds from the pool
  /// @param _allocator Address of the allocator
  /// @return 'true' if the allocator is a pool manager, otherwise false
  function _isValidAllocator(address _allocator) internal view override returns (bool) {
    return allo.isPoolManager(poolId, _allocator);
  }

  /// @notice This contract should be able to receive native token
  receive() external payable {}
}
